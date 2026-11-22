// Package parse импортирует ключи/подписки из Telegram-ботов:
// vless://, vmess://, trojan://, ss://, hysteria2://, tuic://, anytls://,
// подписки (base64/текст), sing-box JSON и Clash YAML.
package parse

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"

	"FirmyVPN/internal/model"

	"github.com/google/uuid"
	"gopkg.in/yaml.v3"
)

// ParseInput разбирает произвольный текст: ссылки (по строкам), base64-подписку,
// sing-box JSON или Clash YAML. Возвращает импортированные серверы.
func ParseInput(text string, source, subURL, subName string) ([]*model.Server, []string) {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil, []string{"пустой ввод"}
	}

	// sing-box JSON или одиночный outbound JSON
	if strings.HasPrefix(text, "{") {
		servers, errs := parseJSONConfig(text, source, subURL, subName)
		return servers, errs
	}

	// Clash YAML
	if isClashYAML(text) {
		servers, errs := parseClashYAML(text, source, subURL, subName)
		return servers, errs
	}

	// base64-подписка (целиком)
	if !strings.Contains(text, "://") && !strings.Contains(text, "\n") {
		if dec, err := b64Decode(text); err == nil && strings.Contains(dec, "://") {
			text = dec
		}
	}

	var servers []*model.Server
	var errs []string
	seen := map[string]bool{}

	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(strings.Trim(line, "\r"))
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		// строка может быть сама base64
		if !strings.Contains(line, "://") {
			if dec, err := b64Decode(line); err == nil && strings.Contains(dec, "://") {
				line = strings.TrimSpace(dec)
			}
		}
		srv, err := ParseLink(line)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s: %v", clip(line, 60), err))
			continue
		}
		if seen[srv.URI] {
			continue
		}
		seen[srv.URI] = true
		srv.Source = source
		srv.SubURL = subURL
		srv.SubName = subName
		servers = append(servers, srv)
	}
	return servers, errs
}

// ParseLink разбирает одну ссылку-ключ.
func ParseLink(raw string) (*model.Server, error) {
	raw = strings.TrimSpace(raw)
	lower := strings.ToLower(raw)
	switch {
	case strings.HasPrefix(lower, "vless://"):
		return parseVLESS(raw)
	case strings.HasPrefix(lower, "vmess://"):
		return parseVMess(raw)
	case strings.HasPrefix(lower, "trojan://"):
		return parseTrojan(raw)
	case strings.HasPrefix(lower, "ss://"):
		return parseShadowsocks(raw)
	case strings.HasPrefix(lower, "hysteria2://"), strings.HasPrefix(lower, "hy2://"), strings.HasPrefix(lower, "hysteria://"):
		return parseHysteria2(raw)
	case strings.HasPrefix(lower, "tuic://"):
		return parseTUIC(raw)
	case strings.HasPrefix(lower, "anytls://"):
		return parseAnyTLS(raw)
	default:
		return nil, errors.New("неизвестная схема (поддерживаются vless, vmess, trojan, ss, hysteria2, tuic, anytls)")
	}
}

// ---------- helpers ----------

func b64Decode(s string) (string, error) {
	s = strings.TrimSpace(s)
	s = strings.ReplaceAll(s, "\n", "")
	s = strings.ReplaceAll(s, "\r", "")
	s = strings.ReplaceAll(s, " ", "")
	if s == "" {
		return "", errors.New("пустой base64")
	}
	// нормализуем URL-safe алфавит и паддинг
	s = strings.ReplaceAll(s, "-", "+")
	s = strings.ReplaceAll(s, "_", "/")
	for len(s)%4 != 0 {
		s += "="
	}
	raw, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return "", err
	}
	return string(raw), nil
}

// clip обрезает строку для компактных сообщений об ошибках.
func clip(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
}

func newServer(srvType, name, host string, port int, raw string, outbound map[string]any) (*model.Server, error) {
	outbound["type"] = srvType
	outb, err := json.Marshal(outbound)
	if err != nil {
		return nil, err
	}
	if name == "" {
		name = fmt.Sprintf("%s:%d", host, port)
	}
	return &model.Server{
		ID:       uuid.NewString(),
		Name:     name,
		Protocol: protoName(srvType),
		Type:     srvType,
		Host:     host,
		Port:     port,
		URI:      raw,
		Outbound: outb,
		AddedAt:  nowMs(),
		Ping:     -1,
	}, nil
}

func protoName(t string) string {
	switch t {
	case "shadowsocks":
		return "shadowsocks"
	default:
		return t
	}
}

func nowMs() int64 { return time.Now().UnixMilli() }

// portOrDefault возвращает порт из URL или дефолт.
func portOrDefault(u *url.URL, def int) int {
	p := u.Port()
	if p == "" {
		return def
	}
	n, err := strconv.Atoi(p)
	if err != nil || n <= 0 || n > 65535 {
		return def
	}
	return n
}

// transportFromQuery собирает sing-box V2Ray-транспорт из query-параметров.
func transportFromQuery(q url.Values) map[string]any {
	t := strings.ToLower(q.Get("type"))
	switch t {
	case "", "tcp":
		return nil
	case "ws", "websocket":
		ws := map[string]any{}
		if p := q.Get("path"); p != "" {
			ws["path"] = p
		}
		headers := map[string]any{}
		if h := q.Get("host"); h != "" {
			headers["Host"] = h
		}
		if len(headers) > 0 {
			ws["headers"] = headers
		}
		if ed := q.Get("earlyDataHeaderName"); ed != "" {
			ws["early_data_header_name"] = ed
		}
		return map[string]any{"type": "ws", "ws": ws}
	case "grpc":
		g := map[string]any{}
		if s := q.Get("serviceName"); s != "" {
			g["service_name"] = s
		}
		return map[string]any{"type": "grpc", "grpc": g}
	case "http":
		h := map[string]any{}
		if p := q.Get("path"); p != "" {
			h["path"] = p
		}
		if hh := q.Get("host"); hh != "" {
			h["host"] = []string{hh}
		}
		return map[string]any{"type": "http", "http": h}
	case "httpupgrade":
		h := map[string]any{}
		if p := q.Get("path"); p != "" {
			h["path"] = p
		}
		if hh := q.Get("host"); hh != "" {
			h["host"] = hh
		}
		return map[string]any{"type": "httpupgrade", "httpupgrade": h}
	case "quic":
		return map[string]any{"type": "quic", "quic": map[string]any{}}
	default:
		return nil
	}
}

// tlsFromQuery собирает блок tls (с поддержкой reality/utls/ech).
func tlsFromQuery(q url.Values) map[string]any {
	sec := strings.ToLower(q.Get("security"))
	if sec == "" {
		sec = "none"
	}
	if sec == "none" {
		return nil
	}
	tls := map[string]any{"enabled": true}
	if sni := firstNonEmpty(q.Get("sni"), q.Get("serverName"), q.Get("host")); sni != "" {
		tls["server_name"] = sni
	}
	if q.Get("insecure") == "1" || strings.EqualFold(q.Get("insecure"), "true") || q.Get("allowInsecure") == "1" {
		tls["insecure"] = true
	}
	if alpn := q.Get("alpn"); alpn != "" {
		tls["alpn"] = strings.Split(alpn, ",")
	}
	if fp := firstNonEmpty(q.Get("fp"), q.Get("fingerprint")); fp != "" {
		tls["utls"] = map[string]any{"enabled": true, "fingerprint": fp}
	}
	if sec == "reality" || q.Get("pbk") != "" {
		r := map[string]any{"enabled": true}
		if pbk := q.Get("pbk"); pbk != "" {
			r["public_key"] = pbk
		}
		if sid := firstNonEmpty(q.Get("sid"), q.Get("shortId")); sid != "" {
			r["short_id"] = sid
		}
		if spx := q.Get("spx"); spx != "" {
			r["spider_x"] = spx
		}
		tls["reality"] = r
	}
	if ech := q.Get("ech"); ech != "" {
		tls["ech"] = map[string]any{"enabled": true, "config": []string{ech}}
	}
	return tls
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

func parseName(u *url.URL) string {
	return strings.TrimSpace(u.Fragment)
}

// ---------- vless ----------

func parseVLESS(raw string) (*model.Server, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("разбор URL: %w", err)
	}
	uuidStr := u.User.Username()
	if uuidStr == "" {
		return nil, errors.New("нет UUID")
	}
	host := u.Hostname()
	if host == "" {
		return nil, errors.New("нет адреса сервера")
	}
	port := portOrDefault(u, 443)
	q := u.Query()

	out := map[string]any{
		"server":      host,
		"server_port": port,
		"uuid":        uuidStr,
	}
	if flow := q.Get("flow"); flow != "" {
		out["flow"] = flow
	}
	if net := q.Get("network"); net != "" {
		out["network"] = strings.Split(net, ",")
	} else if t := q.Get("type"); t != "" && t != "tcp" {
		out["network"] = []string{"tcp", "udp"}
	}
	if tls := tlsFromQuery(q); tls != nil {
		out["tls"] = tls
	}
	if tr := transportFromQuery(q); tr != nil {
		out["transport"] = tr
	}
	if pe := q.Get("packetEncoding"); pe != "" {
		out["packet_encoding"] = pe
	}
	return newServer("vless", parseName(u), host, port, raw, out)
}

// ---------- vmess ----------

func parseVMess(raw string) (*model.Server, error) {
	// vmess://<base64 JSON>
	b64part := strings.TrimPrefix(raw, "vmess://")
	b64part = strings.TrimPrefix(b64part, "VMESS://")
	// иногда в конце #name отдельно
	name := ""
	if idx := strings.Index(b64part, "#"); idx >= 0 {
		if decoded, err := url.QueryUnescape(b64part[idx+1:]); err == nil {
			name = decoded
		}
		b64part = b64part[:idx]
	}
	jsonStr, err := b64Decode(b64part)
	if err != nil {
		return nil, fmt.Errorf("base64 vmess: %w", err)
	}
	var p struct {
		PS   string `json:"ps"`
		Add  string `json:"add"`
		Port string `json:"port"`
		ID   string `json:"id"`
		AID  string `json:"aid"`
		Scy  string `json:"scy"`
		Net  string `json:"net"`
		Type string `json:"type"`
		Host string `json:"host"`
		Path string `json:"path"`
		TLS  string `json:"tls"`
		SNI  string `json:"sni"`
		ALPN string `json:"alpn"`
		FP   string `json:"fp"`
	}
	if err := json.Unmarshal([]byte(jsonStr), &p); err != nil {
		return nil, fmt.Errorf("JSON vmess: %w", err)
	}
	if p.Add == "" || p.ID == "" {
		return nil, errors.New("vmess: нет адреса или UUID")
	}
	port, _ := strconv.Atoi(strings.TrimSpace(p.Port))
	if port <= 0 {
		port = 443
	}
	if name == "" {
		name = p.PS
	}

	q := url.Values{}
	switch strings.ToLower(p.Net) {
	case "", "tcp":
		// no transport
	case "ws":
		q.Set("type", "ws")
		q.Set("path", p.Path)
		if p.Host != "" {
			q.Set("host", p.Host)
		}
	case "grpc":
		q.Set("type", "grpc")
		q.Set("serviceName", p.Path)
	case "http":
		q.Set("type", "http")
		q.Set("path", p.Path)
		q.Set("host", p.Host)
	case "h2":
		q.Set("type", "http")
		q.Set("path", p.Path)
		q.Set("host", p.Host)
	case "httpupgrade":
		q.Set("type", "httpupgrade")
		q.Set("path", p.Path)
		q.Set("host", p.Host)
	case "quic":
		q.Set("type", "quic")
	}
	if p.TLS != "" && !strings.EqualFold(p.TLS, "none") {
		q.Set("security", "tls")
	}
	if p.SNI != "" {
		q.Set("sni", p.SNI)
	}
	if p.ALPN != "" {
		q.Set("alpn", p.ALPN)
	}
	if p.FP != "" {
		q.Set("fp", p.FP)
	}

	out := map[string]any{
		"server":      p.Add,
		"server_port": port,
		"uuid":        p.ID,
	}
	if scy := p.Scy; scy != "" && scy != "auto" {
		out["security"] = scy
	}
	if aid := p.AID; aid != "" && aid != "0" {
		if n, err := strconv.Atoi(aid); err == nil {
			out["alter_id"] = n
		}
	}
	if netw := strings.ToLower(p.Net); netw != "" && netw != "tcp" {
		out["network"] = []string{"tcp", "udp"}
	}
	if tls := tlsFromQuery(q); tls != nil {
		out["tls"] = tls
	}
	if tr := transportFromQuery(q); tr != nil {
		out["transport"] = tr
	}
	return newServer("vmess", name, p.Add, port, raw, out)
}

// ---------- trojan ----------

func parseTrojan(raw string) (*model.Server, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("разбор URL: %w", err)
	}
	pass := u.User.Username()
	if pass == "" {
		if p, ok := u.User.Password(); ok {
			pass = p
		}
	}
	if pass == "" {
		return nil, errors.New("нет пароля")
	}
	host := u.Hostname()
	if host == "" {
		return nil, errors.New("нет адреса сервера")
	}
	port := portOrDefault(u, 443)
	q := u.Query()

	out := map[string]any{
		"server":      host,
		"server_port": port,
		"password":    pass,
	}
	if net := q.Get("network"); net != "" {
		out["network"] = strings.Split(net, ",")
	}
	if tls := tlsFromQuery(q); tls != nil {
		out["tls"] = tls
	} else {
		out["tls"] = map[string]any{"enabled": true, "server_name": host}
	}
	if tr := transportFromQuery(q); tr != nil {
		out["transport"] = tr
	}
	return newServer("trojan", parseName(u), host, port, raw, out)
}

// ---------- shadowsocks ----------

func parseShadowsocks(raw string) (*model.Server, error) {
	rest := strings.TrimPrefix(raw, "ss://")
	rest = strings.TrimPrefix(rest, "SS://")
	frag := ""
	if idx := strings.Index(rest, "#"); idx >= 0 {
		if decoded, err := url.QueryUnescape(rest[idx+1:]); err == nil {
			frag = decoded
		}
		rest = rest[:idx]
	}
	query := ""
	if idx := strings.Index(rest, "?"); idx >= 0 {
		query = rest[idx+1:]
		rest = rest[:idx]
	}

	var method, password, host string
	var port int

	if strings.Contains(rest, "@") {
		// SIP002: base64(method:password)@host:port
		at := strings.LastIndex(rest, "@")
		userinfo := rest[:at]
		hostport := rest[at+1:]
		decoded, err := b64Decode(userinfo)
		if err != nil {
			// возможно, method:password в открытом виде (URL-encoded)
			plain, err2 := url.QueryUnescape(userinfo)
			if err2 != nil {
				return nil, fmt.Errorf("ss userinfo: %w", err)
			}
			decoded = plain
		}
		// method:password@host:port иногда и в декодированной части
		if c := strings.Index(decoded, "@"); c >= 0 {
			userinfo = decoded[:c]
			hostport = decoded[c+1:]
		} else {
			userinfo = decoded
		}
		cp := strings.SplitN(userinfo, ":", 2)
		if len(cp) != 2 {
			return nil, errors.New("ss: неверный формат method:password")
		}
		method, password = cp[0], cp[1]
		host, port = splitHostPort(hostport, 8388)
	} else {
		// легаси: base64(method:password@host:port)
		decoded, err := b64Decode(rest)
		if err != nil {
			return nil, fmt.Errorf("ss base64: %w", err)
		}
		at := strings.LastIndex(decoded, "@")
		if at < 0 {
			return nil, errors.New("ss: нет @ в легаси-формате")
		}
		userinfo := decoded[:at]
		hostport := decoded[at+1:]
		cp := strings.SplitN(userinfo, ":", 2)
		if len(cp) != 2 {
			return nil, errors.New("ss: неверный формат method:password")
		}
		method, password = cp[0], cp[1]
		host, port = splitHostPort(hostport, 8388)
	}
	if host == "" {
		return nil, errors.New("ss: нет адреса сервера")
	}

	out := map[string]any{
		"server":      host,
		"server_port": port,
		"method":      method,
		"password":    password,
	}
	// plugin (simple-obfs / v2ray-plugin) не поддерживается sing-box — пропускаем
	_ = query
	return newServer("shadowsocks", frag, host, port, raw, out)
}

func splitHostPort(s string, defPort int) (string, int) {
	s = strings.TrimSpace(s)
	// [v6]:port
	if strings.HasPrefix(s, "[") {
		if c := strings.Index(s, "]"); c > 0 {
			host := s[1:c]
			rest := s[c+1:]
			if strings.HasPrefix(rest, ":") {
				if p, err := strconv.Atoi(rest[1:]); err == nil {
					return host, p
				}
			}
			return host, defPort
		}
	}
	if c := strings.LastIndex(s, ":"); c > 0 {
		if p, err := strconv.Atoi(s[c+1:]); err == nil && p > 0 && p < 65536 {
			return s[:c], p
		}
	}
	return s, defPort
}

// ---------- hysteria2 ----------

func parseHysteria2(raw string) (*model.Server, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("разбор URL: %w", err)
	}
	pass := u.User.Username()
	if pass == "" {
		if p, ok := u.User.Password(); ok {
			pass = p
		}
	}
	host := u.Hostname()
	if host == "" {
		return nil, errors.New("нет адреса сервера")
	}
	port := portOrDefault(u, 443)
	q := u.Query()

	out := map[string]any{
		"server":      host,
		"server_port": port,
	}
	if pass != "" {
		out["password"] = pass
	}
	if up := q.Get("up"); up != "" {
		if n, err := strconv.Atoi(up); err == nil {
			out["up_mbps"] = n
		}
	}
	if down := q.Get("down"); down != "" {
		if n, err := strconv.Atoi(down); err == nil {
			out["down_mbps"] = n
		}
	}
	if obfs := q.Get("obfs"); obfs != "" {
		o := map[string]any{"type": obfs}
		if op := q.Get("obfs-password"); op != "" {
			o["password"] = op
		}
		out["obfs"] = o
	}
	tls := map[string]any{"enabled": true}
	if sni := firstNonEmpty(q.Get("sni"), q.Get("peer")); sni != "" {
		tls["server_name"] = sni
	} else {
		tls["server_name"] = host
	}
	if q.Get("insecure") == "1" || strings.EqualFold(q.Get("insecure"), "true") {
		tls["insecure"] = true
	}
	if alpn := q.Get("alpn"); alpn != "" {
		tls["alpn"] = strings.Split(alpn, ",")
	}
	out["tls"] = tls
	return newServer("hysteria2", parseName(u), host, port, raw, out)
}

// ---------- tuic ----------

func parseTUIC(raw string) (*model.Server, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("разбор URL: %w", err)
	}
	uuidStr := u.User.Username()
	pass := ""
	if p, ok := u.User.Password(); ok {
		pass = p
	}
	if uuidStr == "" || pass == "" {
		return nil, errors.New("tuic: нужны UUID:пароль")
	}
	host := u.Hostname()
	if host == "" {
		return nil, errors.New("нет адреса сервера")
	}
	port := portOrDefault(u, 443)
	q := u.Query()

	out := map[string]any{
		"server":      host,
		"server_port": port,
		"uuid":        uuidStr,
		"password":    pass,
	}
	if cc := q.Get("congestion_control"); cc != "" {
		out["congestion_control"] = cc
	}
	if urm := q.Get("udp_relay_mode"); urm != "" {
		out["udp_relay_mode"] = urm
	}
	if hb := q.Get("heartbeat"); hb != "" {
		out["heartbeat"] = hb
	}
	if q.Get("zero_rtt_handshake") == "1" {
		out["zero_rtt_handshake"] = true
	}
	if net := q.Get("network"); net != "" {
		out["network"] = strings.Split(net, ",")
	}
	tls := map[string]any{"enabled": true}
	if sni := q.Get("sni"); sni != "" {
		tls["server_name"] = sni
	} else {
		tls["server_name"] = host
	}
	if q.Get("allow_insecure") == "1" || q.Get("insecure") == "1" {
		tls["insecure"] = true
	}
	if alpn := q.Get("alpn"); alpn != "" {
		tls["alpn"] = strings.Split(alpn, ",")
	}
	out["tls"] = tls
	return newServer("tuic", parseName(u), host, port, raw, out)
}

// ---------- anytls ----------

func parseAnyTLS(raw string) (*model.Server, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("разбор URL: %w", err)
	}
	pass := u.User.Username()
	if pass == "" {
		if p, ok := u.User.Password(); ok {
			pass = p
		}
	}
	host := u.Hostname()
	if host == "" {
		return nil, errors.New("нет адреса сервера")
	}
	port := portOrDefault(u, 443)
	q := u.Query()

	out := map[string]any{
		"server":      host,
		"server_port": port,
	}
	if pass != "" {
		out["password"] = pass
	}
	tls := map[string]any{"enabled": true}
	if sni := q.Get("sni"); sni != "" {
		tls["server_name"] = sni
	} else {
		tls["server_name"] = host
	}
	if q.Get("insecure") == "1" || q.Get("allow_insecure") == "1" {
		tls["insecure"] = true
	}
	if alpn := q.Get("alpn"); alpn != "" {
		tls["alpn"] = strings.Split(alpn, ",")
	}
	out["tls"] = tls
	return newServer("anytls", parseName(u), host, port, raw, out)
}

// ---------- sing-box JSON ----------

func parseJSONConfig(text, source, subURL, subName string) ([]*model.Server, []string) {
	var generic map[string]any
	if err := json.Unmarshal([]byte(text), &generic); err != nil {
		return nil, []string{"невалидный JSON: " + err.Error()}
	}
	var candidates []map[string]any

	if arr, ok := generic["outbounds"].([]any); ok {
		for _, it := range arr {
			if m, ok := it.(map[string]any); ok {
				candidates = append(candidates, m)
			}
		}
	} else if t, ok := generic["type"].(string); ok && isOutboundType(t) {
		candidates = append(candidates, generic)
	} else {
		return nil, []string{"в JSON не найдены outbounds"}
	}

	var servers []*model.Server
	var errs []string
	seen := map[string]bool{}
	for _, m := range candidates {
		t, _ := m["type"].(string)
		if !isOutboundType(t) {
			continue // direct/block/dns/urltest/select — не серверы
		}
		// листовые ноды: без detour или detour=direct
		if detour, ok := m["detour"].(string); ok && detour != "" && detour != "direct" {
			continue
		}
		delete(m, "detour")
		delete(m, "tag")
		raw, err := json.Marshal(m)
		if err != nil {
			errs = append(errs, err.Error())
			continue
		}
		key := string(raw)
		if seen[key] {
			continue
		}
		seen[key] = true

		host, _ := m["server"].(string)
		port := 0
		switch v := m["server_port"].(type) {
		case float64:
			port = int(v)
		case string:
			port, _ = strconv.Atoi(v)
		}
		name := ""
		if n, ok := m["name"].(string); ok {
			name = n
		}
		if name == "" {
			if n, ok := m["ps"].(string); ok {
				name = n
			}
		}
		srv, err := newServer(t, name, host, port, string(raw), m)
		if err != nil {
			errs = append(errs, err.Error())
			continue
		}
		srv.Source = source
		srv.SubURL = subURL
		srv.SubName = subName
		servers = append(servers, srv)
	}
	if len(servers) == 0 && len(errs) == 0 {
		errs = append(errs, "в конфиге нет подходящих серверов")
	}
	return servers, errs
}

func isOutboundType(t string) bool {
	switch t {
	case "vless", "vmess", "trojan", "shadowsocks", "hysteria2", "hysteria", "tuic", "anytls",
		"wireguard", "ssh", "snell", "shadowtls", "naive", "tor", "mieru", "hysteria3":
		return true
	}
	return false
}

// ---------- Clash YAML ----------

func isClashYAML(text string) bool {
	head := text
	if len(head) > 4096 {
		head = head[:4096]
	}
	return strings.Contains(head, "proxies:") || strings.Contains(head, "proxy-providers:")
}

type clashProxy struct {
	Name           string            `yaml:"name"`
	Type           string            `yaml:"type"`
	Server         string            `yaml:"server"`
	Port           int               `yaml:"port"`
	UUID           string            `yaml:"uuid"`
	Password       string            `yaml:"password"`
	Cipher         string            `yaml:"cipher"`
	AlterID        int               `yaml:"alterId"`
	Network        string            `yaml:"network"`
	TLS            bool              `yaml:"tls"`
	SNI            string            `yaml:"servername"`
	SkipCertVerify bool              `yaml:"skip-cert-verify"`
	Flow           string            `yaml:"flow"`
	UDP            bool              `yaml:"udp"`
	WSOpts         *clashWSOpts      `yaml:"ws-opts"`
	GRPCOpts       *clashGRPCOpts    `yaml:"grpc-opts"`
	RealityOpts    *clashRealityOpts `yaml:"reality-opts"`
	ALPN           []string          `yaml:"alpn"`
	Fingerprint    string            `yaml:"client-fingerprint"`
	Obfs           string            `yaml:"obfs"`
	ObfsPassword   string            `yaml:"obfs-password"`
	CongestionCtrl string            `yaml:"congestion-control"`
	UDPRelayMode   string            `yaml:"udp-relay-mode"`
	Up             string            `yaml:"up"`
	Down           string            `yaml:"down"`
	Insecure       bool              `yaml:"insecure"`
}

type clashWSOpts struct {
	Path         string            `yaml:"path"`
	Headers      map[string]string `yaml:"headers"`
	MaxEarlyData int               `yaml:"max-early-data"`
}

type clashGRPCOpts struct {
	ServiceName string `yaml:"grpc-service-name"`
}

type clashRealityOpts struct {
	PublicKey string `yaml:"public-key"`
	ShortID   string `yaml:"short-id"`
}

func parseClashYAML(text, source, subURL, subName string) ([]*model.Server, []string) {
	var doc struct {
		Proxies []clashProxy `yaml:"proxies"`
	}
	if err := yaml.Unmarshal([]byte(text), &doc); err != nil {
		return nil, []string{"Clash YAML: " + err.Error()}
	}
	var servers []*model.Server
	var errs []string
	seen := map[string]bool{}
	for _, p := range doc.Proxies {
		srv, err := clashToServer(p)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s: %v", p.Name, err))
			continue
		}
		if srv == nil {
			continue
		}
		if seen[srv.URI] {
			continue
		}
		seen[srv.URI] = true
		srv.Source = source
		srv.SubURL = subURL
		srv.SubName = subName
		servers = append(servers, srv)
	}
	if len(servers) == 0 && len(errs) == 0 {
		errs = append(errs, "в Clash-конфиге нет прокси")
	}
	return servers, errs
}

func clashToServer(p clashProxy) (*model.Server, error) {
	if p.Server == "" || p.Port == 0 {
		return nil, errors.New("нет server/port")
	}
	t := strings.ToLower(strings.TrimSpace(p.Type))
	var out map[string]any

	switch t {
	case "vless":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "uuid": p.UUID,
		}
		if p.Flow != "" {
			out["flow"] = p.Flow
		}
	case "vmess":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "uuid": p.UUID,
		}
		if p.Cipher != "" && p.Cipher != "auto" {
			out["security"] = p.Cipher
		}
		if p.AlterID > 0 {
			out["alter_id"] = p.AlterID
		}
	case "trojan":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "password": p.Password,
		}
	case "ss", "shadowsocks":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "method": p.Cipher, "password": p.Password,
		}
		t = "shadowsocks"
	case "hysteria2", "hy2":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "password": p.Password,
		}
		if p.Up != "" {
			if n, err := strconv.Atoi(strings.TrimSuffix(p.Up, "Mbps")); err == nil {
				out["up_mbps"] = n
			}
		}
		if p.Down != "" {
			if n, err := strconv.Atoi(strings.TrimSuffix(p.Down, "Mbps")); err == nil {
				out["down_mbps"] = n
			}
		}
		if p.Obfs != "" {
			o := map[string]any{"type": p.Obfs}
			if p.ObfsPassword != "" {
				o["password"] = p.ObfsPassword
			}
			out["obfs"] = o
		}
		t = "hysteria2"
	case "tuic":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "uuid": p.UUID, "password": p.Password,
		}
		if p.CongestionCtrl != "" {
			out["congestion_control"] = p.CongestionCtrl
		}
		if p.UDPRelayMode != "" {
			out["udp_relay_mode"] = p.UDPRelayMode
		}
	case "anytls":
		out = map[string]any{
			"server": p.Server, "server_port": p.Port, "password": p.Password,
		}
	default:
		return nil, fmt.Errorf("тип %q не поддерживается", p.Type)
	}

	// транспорт
	switch strings.ToLower(p.Network) {
	case "ws":
		ws := map[string]any{}
		if p.WSOpts != nil {
			if p.WSOpts.Path != "" {
				ws["path"] = p.WSOpts.Path
			}
			if len(p.WSOpts.Headers) > 0 {
				ws["headers"] = p.WSOpts.Headers
			}
			if p.WSOpts.MaxEarlyData > 0 {
				ws["max_early_data"] = uint32(p.WSOpts.MaxEarlyData)
				ws["early_data_header_name"] = "Sec-WebSocket-Protocol"
			}
		}
		out["transport"] = map[string]any{"type": "ws", "ws": ws}
		out["network"] = []string{"tcp", "udp"}
	case "grpc":
		g := map[string]any{}
		if p.GRPCOpts != nil && p.GRPCOpts.ServiceName != "" {
			g["service_name"] = p.GRPCOpts.ServiceName
		}
		out["transport"] = map[string]any{"type": "grpc", "grpc": g}
		out["network"] = []string{"tcp", "udp"}
	case "h2", "http":
		out["transport"] = map[string]any{"type": "http", "http": map[string]any{}}
	}

	// tls
	needTLS := p.TLS || t == "trojan" || t == "hysteria2" || t == "tuic" || t == "anytls"
	if needTLS || p.SNI != "" || p.RealityOpts != nil {
		tls := map[string]any{"enabled": true}
		if p.SNI != "" {
			tls["server_name"] = p.SNI
		} else {
			tls["server_name"] = p.Server
		}
		if p.SkipCertVerify || p.Insecure {
			tls["insecure"] = true
		}
		if len(p.ALPN) > 0 {
			tls["alpn"] = p.ALPN
		}
		if p.Fingerprint != "" {
			tls["utls"] = map[string]any{"enabled": true, "fingerprint": p.Fingerprint}
		}
		if p.RealityOpts != nil && p.RealityOpts.PublicKey != "" {
			r := map[string]any{"enabled": true, "public_key": p.RealityOpts.PublicKey}
			if p.RealityOpts.ShortID != "" {
				r["short_id"] = p.RealityOpts.ShortID
			}
			tls["reality"] = r
		}
		out["tls"] = tls
	}
	if t == "vless" || t == "vmess" || t == "trojan" {
		out["network"] = []string{"tcp", "udp"}
	}

	raw, err := json.Marshal(out)
	if err != nil {
		return nil, err
	}
	srv, err := newServer(t, p.Name, p.Server, p.Port, string(raw), out)
	if err != nil {
		return nil, err
	}
	return srv, nil
}
