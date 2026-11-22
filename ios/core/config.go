package firmycore

// Конфиг sing-box для iOS: всегда TUN (Network Extension), без системного
// прокси и без локального mixed-inbound — режим «прокси» на iOS не нужен.
// Убраны только Windows-штуки, всё остальное совпадает с PC-версией
// (internal/engine.BuildConfig).

import (
	"encoding/json"
	"fmt"
	"net"
	"net/url"
	"strings"

	"firmyvpn/ios/core/model"
)

const (
	clashController = "127.0.0.1:9097"
	tunIPv4         = "172.19.0.1"
	tunIPv6         = "fdfe:dcba:9876::1"
)

func dohServer(tag, ip, serverName string) map[string]any {
	return map[string]any{
		"type": "https", "tag": tag,
		"server": ip, "server_port": 443,
		"path":   "/dns-query",
		"tls":    map[string]any{"enabled": true, "server_name": serverName},
		"detour": "proxy",
	}
}

func mtuOf(m int) int {
	if m < 1280 || m > 9000 {
		return 9000
	}
	return m
}

func tunAddrs(noIPv6 bool) []string {
	if noIPv6 {
		return []string{tunIPv4 + "/30"}
	}
	return []string{tunIPv4 + "/30", tunIPv6 + "/126"}
}

func splitList(s string) []string {
	var out []string
	for _, part := range strings.FieldsFunc(s, func(r rune) bool {
		return r == '\n' || r == '\r' || r == ',' || r == ';' || r == ' ' || r == '\t'
	}) {
		p := strings.TrimPrefix(strings.ToLower(strings.TrimSpace(part)), "*.")
		p = strings.TrimPrefix(p, "https://")
		p = strings.TrimPrefix(p, "http://")
		if p = strings.Trim(p, "/"); p != "" {
			out = append(out, p)
		}
	}
	return out
}

var adDomains = []string{
	"doubleclick.net", "googlesyndication.com", "googleadservices.com",
	"adservice.google.com", "pagead2.googlesyndication.com",
	"adnxs.com", "criteo.com", "criteo.net", "taboola.com", "outbrain.com",
	"hotjar.com", "mixpanel.com", "segment.io", "amplitude.com",
	"branch.io", "appsflyer.com", "adjust.com", "singular.net",
	"scorecardresearch.com", "quantserve.com", "zedo.com", "advertising.com",
	"adskeeper.com", "propellerads.com", "popads.net", "adsterra.com",
	"mgid.com", "revcontent.com", "yllix.com", "adcash.com",
	"an.yandex.ru", "ads.yandex.ru", "mc.yandex.ru", "sync.megapush.com",
	"amazon-adsystem.com", "ad.doubleclick.net", "ads.yahoo.com",
	"adsrvr.org", "demdex.net", "everesttech.net", "rubiconproject.com",
	"pubmatic.com", "openx.net", "casalemedia.com", "lijit.com",
	"newrelic.com", "nr-data.net", "clarity.ms", "bat.bing.com",
	"connect.facebook.net", "facebook.net", "tr.snapchat.com",
	"analytics.tiktok.com", "ads.tiktok.com", "applog.uc.cn",
	"sentry.io", "bugsnag.com", "crashlytics.com",
}

func dnsConfig(preset, custom string) ([]any, string) {
	if c := strings.TrimSpace(custom); c != "" {
		if u, err := url.Parse(c); err == nil && (u.Scheme == "https" || u.Scheme == "http") && u.Hostname() != "" {
			return []any{dohServer("dns-custom", u.Hostname(), u.Hostname())}, "dns-custom"
		}
		host := c
		if h, _, err := net.SplitHostPort(c); err == nil {
			host = h
		}
		if ip := net.ParseIP(host); ip != nil {
			return []any{map[string]any{
				"type": "udp", "tag": "dns-custom",
				"server": c, "detour": "proxy",
			}}, "dns-custom"
		}
		return []any{dohServer("dns-custom", host, host)}, "dns-custom"
	}
	switch preset {
	case "direct":
		return []any{map[string]any{
			"type": "udp", "tag": "dns-direct",
			"server": "223.5.5.5", "detour": "direct",
		}}, "dns-direct"
	case "cloudflare":
		return []any{dohServer("dns-main", "1.1.1.1", "cloudflare-dns.com")}, "dns-main"
	case "quad9":
		return []any{dohServer("dns-main", "9.9.9.9", "dns.quad9.net")}, "dns-main"
	case "adguard":
		return []any{dohServer("dns-main", "94.140.14.14", "dns.adguard-dns.com")}, "dns-main"
	default: // auto / google
		return []any{dohServer("dns-main", "8.8.8.8", "dns.google")}, "dns-main"
	}
}

// BuildConfig собирает JSON-конфиг sing-box для подключения к серверу на iOS.
// mode на iOS всегда tun; killSwitch применяется приложением через
// NETunnelProviderProtocol.includeAllNetworks.
// Неэкспортно намеренно: gomobile берёт в Libbox.xcframework только
// поддерживаемые типы (строки), а model.Server — внутренний тип пакета.
func buildConfig(srv *model.Server, st *model.Settings, basePath string) ([]byte, error) {
	var srvOut map[string]any
	if err := json.Unmarshal(srv.Outbound, &srvOut); err != nil {
		return nil, fmt.Errorf("разбор outbound сервера: %w", err)
	}
	if t, _ := srvOut["type"].(string); t == "" {
		srvOut["type"] = srv.Type
	}
	srvOut["tag"] = "proxy"

	outbounds := []any{
		srvOut,
		map[string]any{"type": "direct", "tag": "direct"},
		map[string]any{"type": "block", "tag": "block"},
	}

	inbounds := []any{map[string]any{
		"type":           "tun",
		"tag":            "tun-in",
		"interface_name": "FirmyVPN",
		"auto_route":     true,
		"strict_route":   st.StrictRoute,
		"stack":          "mixed",
		"dns_mode":       "hijack",
		"address":        tunAddrs(st.DisableIPv6),
		"mtu":            mtuOf(st.MTU),
	}}

	var rules []any

	if h := strings.TrimSpace(srv.Host); h != "" {
		rules = append(rules, map[string]any{
			"domain_suffix": []string{h},
			"outbound":      "proxy",
		})
	}
	if st.BlockLAN {
		rules = append(rules, map[string]any{
			"ip_cidr": []string{
				"192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12",
				"169.254.0.0/16", "fc00::/7", "fe80::/10",
			},
			"action": "reject",
		})
	}
	if st.DisableIPv6 {
		rules = append(rules, map[string]any{
			"ip_cidr": []string{"::/0"},
			"action":  "reject",
		})
	}
	if st.BlockBT {
		rules = append(rules, map[string]any{
			"protocol": "bittorrent",
			"action":   "reject",
		})
	}
	if st.UdpBlock {
		rules = append(rules, map[string]any{
			"network": []string{"udp"},
			"action":  "reject",
		})
	}
	if st.BlockAds {
		rules = append(rules, map[string]any{
			"domain_suffix": adDomains,
			"action":        "reject",
		})
	}
	for _, d := range splitList(st.BypassDomains) {
		if ip := net.ParseIP(d); ip != nil || strings.Contains(d, "/") {
			rules = append(rules, map[string]any{"ip_cidr": []string{d}, "outbound": "direct"})
		} else {
			rules = append(rules, map[string]any{"domain_suffix": []string{d}, "outbound": "direct"})
		}
	}

	dnsServers, dnsFinal := dnsConfig(st.DNS, st.CustomDNS)

	cfg := map[string]any{
		"log": map[string]any{
			"level":     st.LogLevel,
			"timestamp": true,
		},
		"dns": map[string]any{
			"servers": dnsServers,
			"final":   dnsFinal,
		},
		"inbounds":  inbounds,
		"outbounds": outbounds,
		"route": map[string]any{
			"rules":                 rules,
			"final":                 "proxy",
			"auto_detect_interface": true,
			"find_process":          false,
		},
		"experimental": map[string]any{
			"cache_file": map[string]any{
				"enabled": true,
				"path":    basePath + "/cache.db",
			},
			"clash_api": map[string]any{
				"external_controller": clashController,
			},
		},
	}
	return json.Marshal(cfg)
}
