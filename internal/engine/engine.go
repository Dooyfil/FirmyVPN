// Package engine — ядро FirmyVPN: сборка конфига sing-box, запуск/остановка
// туннеля, статистика (clash API), пинг, тест скорости, kill switch.
package engine

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"FirmyVPN/internal/model"
	"FirmyVPN/internal/winutil"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	singlog "github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	singjson "github.com/sagernet/sing/common/json"
)

const (
	clashController = "127.0.0.1:9097"
	tunIPv4         = "172.19.0.1"
	tunIPv6         = "fdfe:dcba:9876::1"
)

// Engine управляет одним инстансом sing-box.
type Engine struct {
	mu        sync.Mutex
	inst      *box.Box
	server    *model.Server
	settings  model.Settings
	status    model.Status
	fails     int
	switching bool

	logFn   func(level, msg string)
	stateFn func(model.Status)

	stopStats chan struct{}
	statsDone chan struct{}

	// живой прогресс теста скорости
	spMu    sync.Mutex
	spPhase string
	spDone  int64
	spTotal int64
}

// New создаёт движок.
func New() *Engine {
	return &Engine{settings: model.DefaultSettings()}
}

// SetLogSink — колбэк строк лога ядра.
func (e *Engine) SetLogSink(fn func(level, msg string)) { e.logFn = fn }

// SetStateSink — колбэк изменений статуса.
func (e *Engine) SetStateSink(fn func(model.Status)) { e.stateFn = fn }

// WriteMessage реализует log.PlatformWriter — сюда приходят все логи sing-box.
func (e *Engine) WriteMessage(level singlog.Level, message string) {
	if e.logFn != nil {
		e.logFn(levelName(level), message)
	}
}

func levelName(l singlog.Level) string {
	switch l {
	case singlog.LevelTrace:
		return "trace"
	case singlog.LevelDebug:
		return "debug"
	case singlog.LevelInfo:
		return "info"
	case singlog.LevelWarn:
		return "warn"
	case singlog.LevelError:
		return "error"
	case singlog.LevelFatal:
		return "fatal"
	case singlog.LevelPanic:
		return "panic"
	default:
		return "info"
	}
}

// Status возвращает текущий статус.
func (e *Engine) Status() model.Status {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.status
}

// Connected — подключено ли ядро.
func (e *Engine) Connected() bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.inst != nil
}

func (e *Engine) emitStatus() {
	if e.stateFn == nil {
		return
	}
	e.mu.Lock()
	fn := e.stateFn
	st := e.status
	e.mu.Unlock()
	fn(st)
}

// ---------- сборка конфига ----------

func dohServer(tag, ip, serverName string) map[string]any {
	return map[string]any{
		"type": "https", "tag": tag,
		"server": ip, "server_port": 443,
		"path":   "/dns-query",
		"tls":    map[string]any{"enabled": true, "server_name": serverName},
		"detour": "proxy",
	}
}

// mtuOf — MTU TUN-интерфейса (по умолчанию 9000).
func mtuOf(m int) int {
	if m < 1280 || m > 9000 {
		return 9000
	}
	return m
}

// tunAddrs — адреса TUN; при отключённом IPv6 оставляем только IPv4.
func tunAddrs(noIPv6 bool) []string {
	if noIPv6 {
		return []string{tunIPv4 + "/30"}
	}
	return []string{tunIPv4 + "/30", tunIPv6 + "/126"}
}

// splitList режет список доменов/подсетей по переносам строк и запятым.
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

// adDomains — домены рекламы и трекеров для режима «блокировать рекламу».
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
	"adjust.com", "sentry.io", "bugsnag.com", "crashlytics.com",
}

func dnsConfig(preset, custom string) ([]any, string) {
	// свой DNS-адрес имеет приоритет над пресетом
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
		// обычное доменное имя → DoH с этим же именем (сертификат покрывает его)
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

// BuildConfig собирает JSON-конфиг sing-box для подключения к серверу.
func BuildConfig(srv *model.Server, st model.Settings, cachePath string) ([]byte, error) {
	port := st.ProxyPort
	if port <= 0 {
		port = 10808
	}

	// outbound сервера (из импортированного ключа)
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

	// inbounds
	var inbounds []any
	if st.Mode == "tun" {
		inbounds = append(inbounds, map[string]any{
			"type":           "tun",
			"tag":            "tun-in",
			"interface_name": "FirmyVPN",
			"auto_route":     true,
			"strict_route":   st.StrictRoute,
			"stack":          "mixed",
			"dns_mode":       "hijack",
			"address":        tunAddrs(st.DisableIPv6),
			"mtu":            mtuOf(st.MTU),
		})
	}
	inbounds = append(inbounds, map[string]any{
		"type":             "mixed",
		"tag":              "mixed-in",
		"listen":           "127.0.0.1",
		"listen_port":      port,
		"set_system_proxy": st.Mode == "proxy" && st.SetSystemProxy,
	})

	// правила маршрутизации
	var rules []any

	// трафик до самого VPN-сервера всегда идёт мимо правил блокировки
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
	// домены/подсети, которые должны идти мимо VPN
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
				"path":    cachePath,
			},
			"clash_api": map[string]any{
				"external_controller": clashController,
			},
		},
	}
	return json.Marshal(cfg)
}

// ---------- жизненный цикл ----------

// Start запускает туннель к указанному серверу.
func (e *Engine) Start(srv *model.Server, st model.Settings) error {
	e.mu.Lock()
	if e.inst != nil {
		e.mu.Unlock()
		return fmt.Errorf("уже подключено к %s", e.status.ServerName)
	}
	e.settings = st
	e.status = model.Status{
		Connecting: true,
		Mode:       st.Mode,
		ServerID:   srv.ID,
		ServerName: srv.Name,
		Protocol:   srv.Protocol,
	}
	e.mu.Unlock()
	e.emitStatus()

	cachePath := filepath.Join(cacheDir(), "cache.db")
	cfgBytes, err := BuildConfig(srv, st, cachePath)
	if err != nil {
		e.failStatus(err)
		return err
	}

	ctx := include.Context(context.Background())
	opts, err := singjson.UnmarshalExtendedContext[option.Options](ctx, cfgBytes)
	if err != nil {
		e.failStatus(fmt.Errorf("конфиг ядра: %w", err))
		return fmt.Errorf("конфиг ядра: %w", err)
	}

	inst, err := box.New(box.Options{
		Options:           opts,
		Context:           ctx,
		PlatformLogWriter: e,
	})
	if err != nil {
		e.failStatus(fmt.Errorf("создание ядра: %w", err))
		return fmt.Errorf("создание ядра: %w", err)
	}
	if err := inst.Start(); err != nil {
		_ = inst.Close()
		e.failStatus(fmt.Errorf("запуск ядра: %w", err))
		return fmt.Errorf("запуск ядра: %w", err)
	}

	// ядро поднялось — снимаем kill switch блокировку, если стояла
	_ = winutil.RemoveKillSwitchRules()

	proxyAddr := ""
	if st.Mode == "proxy" || st.Mode == "tun" {
		proxyAddr = fmt.Sprintf("127.0.0.1:%d", port0(st.ProxyPort))
	}

	e.mu.Lock()
	e.inst = inst
	e.server = srv
	e.status = model.Status{
		Connected:  true,
		Mode:       st.Mode,
		ServerID:   srv.ID,
		ServerName: srv.Name,
		Protocol:   srv.Protocol,
		StartedAt:  time.Now().UnixMilli(),
		ProxyAddr:  proxyAddr,
	}
	e.fails = 0
	e.stopStats = make(chan struct{})
	e.statsDone = make(chan struct{})
	stop, done := e.stopStats, e.statsDone
	e.mu.Unlock()
	e.emitStatus()

	go e.statsLoop(stop, done)
	return nil
}

func port0(p int) int {
	if p <= 0 {
		return 10808
	}
	return p
}

func (e *Engine) failStatus(err error) {
	e.mu.Lock()
	e.status = model.Status{
		Mode:       e.settings.Mode,
		Connecting: false,
		Error:      err.Error(),
	}
	e.mu.Unlock()
	e.emitStatus()
}

// Stop останавливает туннель (graceful).
func (e *Engine) Stop() error {
	err := e.closeInstance()
	e.mu.Lock()
	e.status = model.Status{Mode: e.settings.Mode}
	e.mu.Unlock()
	e.emitStatus()
	return err
}

// closeInstance закрывает текущее ядро, НЕ трогая статус (используется при
// бесшовной смене сервера — UI всё это время остаётся «подключённым»).
func (e *Engine) closeInstance() error {
	e.mu.Lock()
	if e.inst == nil {
		e.mu.Unlock()
		return nil
	}
	inst := e.inst
	e.inst = nil
	stop, done := e.stopStats, e.statsDone
	e.mu.Unlock()

	if stop != nil {
		close(stop)
		select {
		case <-done:
		case <-time.After(3 * time.Second):
		}
	}
	return inst.Close()
}

// Switch — бесшовная смена сервера/региона. Ядро перезапускается на новом
// outbound'е, но статус всё время остаётся «подключено» (флаг switching),
// поэтому отключаться не нужно: трафик просто переезжает на другой узел.
func (e *Engine) Switch(srv *model.Server, st model.Settings) error {
	e.mu.Lock()
	prev := e.status
	wasUp := e.inst != nil
	e.settings = st
	e.switching = true
	e.status = model.Status{
		Connected:   wasUp,
		Connecting:  true,
		Switching:   true,
		Mode:        st.Mode,
		ServerID:    srv.ID,
		ServerName:  srv.Name,
		Protocol:    srv.Protocol,
		StartedAt:   prev.StartedAt,
		UploadTot:   prev.UploadTot,
		DownloadTot: prev.DownloadTot,
		ProxyAddr:   prev.ProxyAddr,
	}
	e.mu.Unlock()
	e.emitStatus()
	if e.logFn != nil {
		e.logFn("info", "смена сервера → "+srv.Name)
	}

	if wasUp {
		_ = e.closeInstance()
	}

	err := e.Start(srv, st)

	// статистика сессии не должна обнуляться при смене узла
	e.mu.Lock()
	e.switching = false
	if err == nil {
		if prev.StartedAt == 0 {
			e.status.StartedAt = time.Now().UnixMilli()
		} else {
			e.status.StartedAt = prev.StartedAt
		}
		e.status.UploadTot = prev.UploadTot + e.status.UploadTot
		e.status.DownloadTot = prev.DownloadTot + e.status.DownloadTot
	}
	e.mu.Unlock()
	e.emitStatus()
	return err
}

// statsLoop опрашивает clash API раз в секунду и шлёт статус в UI.
func (e *Engine) statsLoop(stop <-chan struct{}, done chan<- struct{}) {
	defer close(done)
	client := &http.Client{Timeout: 2 * time.Second}
	var prevUp, prevDown int64
	first := true

	for {
		select {
		case <-stop:
			return
		case <-time.After(1 * time.Second):
		}

		up, down, err := fetchTotals(client)
		if err != nil {
			e.mu.Lock()
			e.fails++
			fails := e.fails
			e.mu.Unlock()
			if fails >= 3 {
				e.onConnectionLost()
				return
			}
			continue
		}
		e.mu.Lock()
		e.fails = 0
		e.mu.Unlock()

		var du, dd int64
		if !first {
			du = up - prevUp
			dd = down - prevDown
		}
		first = false
		prevUp, prevDown = up, down
		if du < 0 {
			du = 0
		}
		if dd < 0 {
			dd = 0
		}

		e.mu.Lock()
		if e.inst == nil {
			e.mu.Unlock()
			return
		}
		e.status.Upload = du
		e.status.Download = dd
		e.status.UploadTot = up
		e.status.DownloadTot = down
		e.mu.Unlock()
		e.emitStatus()
	}
}

// onConnectionLost — ядро умерло неожиданно: закрываем остатки,
// при включённом kill switch блокируем интернет.
func (e *Engine) onConnectionLost() {
	e.mu.Lock()
	if e.inst == nil {
		e.mu.Unlock()
		return
	}
	inst := e.inst
	e.inst = nil
	st := e.settings
	e.status.Connected = false
	e.status.Connecting = false
	e.status.Error = "соединение потеряно"
	e.status.Upload = 0
	e.status.Download = 0
	e.mu.Unlock()

	_ = inst.Close()

	if st.KillSwitch {
		if err := winutil.AddKillSwitchRules(); err == nil {
			e.mu.Lock()
			e.status.Error = "связь потеряна — kill switch заблокировал интернет"
			e.mu.Unlock()
		}
	}
	e.emitStatus()
}

func fetchTotals(client *http.Client) (up, down int64, err error) {
	resp, err := client.Get("http://" + clashController + "/connections")
	if err != nil {
		return 0, 0, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return 0, 0, err
	}
	var parsed struct {
		UploadTotal   int64 `json:"uploadTotal"`
		DownloadTotal int64 `json:"downloadTotal"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return 0, 0, err
	}
	return parsed.UploadTotal, parsed.DownloadTotal, nil
}

// ---------- сервисы ----------

// Ping измеряет время установки TCP-соединения с сервером (мс).
func Ping(host string, port int) int {
	start := time.Now()
	conn, err := net.DialTimeout("tcp", net.JoinHostPort(host, strconv.Itoa(port)), 3*time.Second)
	if err != nil {
		return -1
	}
	_ = conn.Close()
	return int(time.Since(start).Milliseconds())
}

// testClient собирает HTTP-клиент теста скорости: в режиме proxy запросы идут
// через локальный прокси, в режиме tun — через системный маршрут (туннель).
func (e *Engine) testClient() *http.Client {
	e.mu.Lock()
	st := e.settings
	connected := e.inst != nil
	e.mu.Unlock()

	transport := &http.Transport{DisableKeepAlives: false}
	if connected && st.Mode == "proxy" {
		u, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port0(st.ProxyPort)))
		transport.Proxy = http.ProxyURL(u)
	}
	return &http.Client{Transport: transport, Timeout: 150 * time.Second}
}

const (
	speedURL    = "https://speed.cloudflare.com"
	speedDownMB = 50
	speedUpMB   = 20
)

// SpeedProgress отдаёт живой прогресс текущего этапа теста (байты).
func (e *Engine) SpeedProgress() map[string]any {
	e.spMu.Lock()
	defer e.spMu.Unlock()
	return map[string]any{
		"phase": e.spPhase,
		"done":  e.spDone,
		"total": e.spTotal,
	}
}

func (e *Engine) setProgress(phase string, total, done int64) {
	e.spMu.Lock()
	e.spPhase, e.spTotal, e.spDone = phase, total, done
	e.spMu.Unlock()
}

func (e *Engine) addProgress(n int64) {
	e.spMu.Lock()
	e.spDone += n
	e.spMu.Unlock()
}

// SpeedLatency — серия замеров задержки: среднее, джиттер, мин/макс.
func (e *Engine) SpeedLatency(ctx context.Context) (model.LatencyResult, error) {
	client := e.testClient()
	e.setProgress("latency", 7, 0)

	var samples []int
	for i := 0; i < 7; i++ {
		if err := ctx.Err(); err != nil {
			return model.LatencyResult{}, err
		}
		start := time.Now()
		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, speedURL+"/__down?bytes=1024", nil)
		resp, err := client.Do(req)
		if err != nil {
			if i == 0 {
				return model.LatencyResult{}, fmt.Errorf("сервер теста недоступен: %w", err)
			}
			continue
		}
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		samples = append(samples, int(time.Since(start).Milliseconds()))
		e.setProgress("latency", 7, int64(i+1))
		time.Sleep(80 * time.Millisecond)
	}
	if len(samples) == 0 {
		return model.LatencyResult{}, fmt.Errorf("сервер теста недоступен")
	}

	minV, maxV, sum := samples[0], samples[0], 0
	for _, s := range samples {
		sum += s
		if s < minV {
			minV = s
		}
		if s > maxV {
			maxV = s
		}
	}
	avg := sum / len(samples)
	jit := 0
	if len(samples) > 1 {
		d := 0
		for i := 1; i < len(samples); i++ {
			d += absI(samples[i] - samples[i-1])
		}
		jit = d / (len(samples) - 1)
	}
	return model.LatencyResult{AvgMs: avg, JitterMs: jit, MinMs: minV, MaxMs: maxV, Samples: len(samples)}, nil
}

func absI(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

// SpeedDown — замер скачивания (несколько мегабайт с живым прогрессом).
func (e *Engine) SpeedDown(ctx context.Context) (float64, error) {
	client := e.testClient()
	size := int64(speedDownMB) * 1_000_000
	e.setProgress("down", size, 0)

	start := time.Now()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet,
		fmt.Sprintf("%s/__down?bytes=%d", speedURL, size), nil)
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("загрузка: %w", err)
	}
	defer resp.Body.Close()

	counter := &countingReader{e: e, r: resp.Body}
	n, err := io.Copy(io.Discard, io.LimitReader(counter, size+1024))
	if err != nil {
		return 0, fmt.Errorf("загрузка: %w", err)
	}
	dur := time.Since(start).Seconds()
	if dur <= 0 {
		return 0, nil
	}
	return float64(n) * 8 / dur / 1e6, nil
}

// SpeedUp — замер загрузки.
func (e *Engine) SpeedUp(ctx context.Context) (float64, error) {
	client := e.testClient()
	size := int64(speedUpMB) * 1_000_000
	e.setProgress("up", size, 0)

	start := time.Now()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, speedURL+"/__up",
		&countingReader{e: e, r: io.LimitReader(foreverReader{}, size)})
	req.ContentLength = size
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("выгрузка: %w", err)
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<20))

	dur := time.Since(start).Seconds()
	if dur <= 0 {
		return 0, nil
	}
	return float64(size) * 8 / dur / 1e6, nil
}

// countingReader копит прочитанные байты в прогресс теста.
type countingReader struct {
	e *Engine
	r io.Reader
	n int64
}

func (c *countingReader) Read(p []byte) (int, error) {
	m, err := c.r.Read(p)
	if m > 0 {
		c.n += int64(m)
		c.e.addProgress(int64(m))
	}
	return m, err
}

// SpeedTest — полный тест (все три этапа разом, для одного вызова).
func (e *Engine) SpeedTest(ctx context.Context) (model.SpeedResult, error) {
	var res model.SpeedResult
	lat, err := e.SpeedLatency(ctx)
	if err != nil {
		return res, err
	}
	res.LatencyMs, res.JitterMs, res.MinMs, res.MaxMs = lat.AvgMs, lat.JitterMs, lat.MinMs, lat.MaxMs
	res.URL = speedURL
	if res.DownloadMbps, err = e.SpeedDown(ctx); err != nil {
		return res, err
	}
	res.UploadMbps, _ = e.SpeedUp(ctx)
	return res, nil
}

// foreverReader — бесконечные нули для тела запроса.
type foreverReader struct{}

func (foreverReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = 0
	}
	return len(p), nil
}

func cacheDir() string {
	base, err := os.UserConfigDir()
	if err != nil {
		return "."
	}
	dir := filepath.Join(base, "FirmyVPN")
	_ = os.MkdirAll(dir, 0o755)
	return dir
}
