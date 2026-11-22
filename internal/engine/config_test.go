package engine

import (
	"context"
	"encoding/json"
	"testing"

	"FirmyVPN/internal/model"

	singjson "github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
)

// fakeServer — минимальный outbound для проверки сборки конфига.
func fakeServer() *model.Server {
	out, _ := json.Marshal(map[string]any{
		"type": "vless", "server": "example.com", "server_port": 443,
		"uuid": "11111111-2222-3333-4444-555555555555",
	})
	return &model.Server{
		ID: "t", Name: "test", Protocol: "vless", Type: "vless",
		Host: "example.com", Port: 443, Outbound: out,
	}
}

// TestBuildConfigParses проверяет, что сгенерированный конфиг sing-box
// проходит строгий разбор (неизвестные поля и опечатки ловятся здесь).
func TestBuildConfigParses(t *testing.T) {
	base := model.DefaultSettings()
	base.Mode = "tun"

	cases := []model.Settings{
		base,
		func() model.Settings {
			s := base
			s.Mode = "proxy"
			s.SetSystemProxy = true
			s.BlockLAN, s.BlockBT = true, true
			s.DisableIPv6, s.UdpBlock, s.BlockAds = true, true, true
			s.MTU = 1400
			s.CustomDNS = "9.9.9.9"
			s.BypassDomains = "example.org\n10.1.0.0/16, bank.ru"
			s.LogLevel = "debug"
			return s
		}(),
		func() model.Settings {
			s := base
			s.CustomDNS = "https://dns.google/dns-query"
			s.DNS = "cloudflare"
			s.StrictRoute = false
			return s
		}(),
	}

	ctx := include.Context(context.Background())
	for i, st := range cases {
		raw, err := BuildConfig(fakeServer(), st, "cache.db")
		if err != nil {
			t.Fatalf("case %d: BuildConfig: %v", i, err)
		}
		if _, err := singjson.UnmarshalExtendedContext[option.Options](ctx, raw); err != nil {
			t.Fatalf("case %d: невалидный конфиг sing-box: %v\n%s", i, err, string(raw))
		}
	}
}

func TestSplitList(t *testing.T) {
	got := splitList(" Example.ORG \n*.ads.example.com, 10.0.0.0/8;https://x.ru/ ")
	want := []string{"example.org", "ads.example.com", "10.0.0.0/8", "x.ru"}
	if len(got) != len(want) {
		t.Fatalf("got %v want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("got %v want %v", got, want)
		}
	}
}
