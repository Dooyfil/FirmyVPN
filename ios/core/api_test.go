package firmycore

import (
	"encoding/json"
	"strings"
	"testing"

	"firmyvpn/ios/core/model"
)

func TestParseInputJSONVLESS(t *testing.T) {
	link := "vless://uuid@example.com:443?type=tcp&security=tls&sni=example.com#MyServer"
	out, err := ParseInputJSON(link, "manual", "", "")
	if err != nil {
		t.Fatal(err)
	}
	var res importResult
	if err := json.Unmarshal([]byte(out), &res); err != nil {
		t.Fatal(err)
	}
	if len(res.Servers) != 1 {
		t.Fatalf("ожидался 1 сервер, получено %d: %s", len(res.Servers), out)
	}
	s := res.Servers[0]
	if s.Host != "example.com" || s.Port != 443 || s.Protocol != "vless" {
		t.Fatalf("неверный сервер: %+v", s)
	}
	if len(s.Outbound) == 0 {
		t.Fatal("пустой outbound")
	}
}

func TestParseInputJSONClashAndBase64(t *testing.T) {
	clash := "proxies:\n  - name: s1\n    type: ss\n    server: a.example\n    port: 8388\n    cipher: aes-128-gcm\n    password: pass\n"
	out, err := ParseInputJSON(clash, "file", "", "")
	if err != nil {
		t.Fatal(err)
	}
	var res importResult
	_ = json.Unmarshal([]byte(out), &res)
	if len(res.Servers) != 1 {
		t.Fatalf("clash: ожидался 1 сервер: %s", out)
	}
}

func TestBuildConfigJSON(t *testing.T) {
	link := "trojan://pass@srv.example:443?sni=srv.example#T"
	out, _ := ParseInputJSON(link, "manual", "", "")
	var res importResult
	if err := json.Unmarshal([]byte(out), &res); err != nil {
		t.Fatal(err)
	}
	sb, _ := json.Marshal(res.Servers[0])
	st, _ := json.Marshal(model.DefaultSettings())
	cfg, err := BuildConfigJSON(string(sb), string(st), "/tmp/firmy")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"type":"tun"`, `"interface_name":"FirmyVPN"`, `"dns_mode":"hijack"`, `127.0.0.1:9097`, `"tag":"proxy"`} {
		if !strings.Contains(cfg, want) {
			t.Fatalf("в конфиге нет %s:\n%s", want, cfg)
		}
	}
	var parsed map[string]any
	if err := json.Unmarshal([]byte(cfg), &parsed); err != nil {
		t.Fatal(err)
	}
}

func TestPingTCPBad(t *testing.T) {
	if got := PingTCP("127.0.0.1", 1, 300); got != -1 {
		t.Fatalf("порт 1 не должен открываться: %d", got)
	}
}
