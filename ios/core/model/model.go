package model

import "encoding/json"

// Server — нормализованная модель сервера/ключа, импортированного пользователем.
type Server struct {
	ID       string          `json:"id"`
	Name     string          `json:"name"`
	Protocol string          `json:"protocol"` // vless, vmess, trojan, shadowsocks, hysteria2, tuic, anytls, wireguard...
	Type     string          `json:"type"`     // sing-box outbound type
	Host     string          `json:"host"`
	Port     int             `json:"port"`
	URI      string          `json:"uri"`
	Outbound json.RawMessage `json:"outbound"` // опции outbound'а sing-box (без type/tag)
	Source   string          `json:"source"`   // manual | subscription | file
	SubURL   string          `json:"subUrl,omitempty"`
	SubName  string          `json:"subName,omitempty"`
	AddedAt  int64           `json:"addedAt"`
	Ping     int             `json:"ping"` // мс, -1 = неизвестно
}

// Subscription — ссылка на подписку.
type Subscription struct {
	URL      string `json:"url"`
	Name     string `json:"name"`
	Count    int    `json:"count"`
	LastSync int64  `json:"lastSync"`
}

// Settings — настройки приложения.
type Settings struct {
	Mode           string `json:"mode"` // "tun" | "proxy"
	KillSwitch     bool   `json:"killSwitch"`
	BlockLAN       bool   `json:"blockLan"`
	BlockBT        bool   `json:"blockBt"`
	SetSystemProxy bool   `json:"setSystemProxy"`
	DNS            string `json:"dns"` // auto | cloudflare | google | quad9 | adguard | direct
	Autostart      bool   `json:"autostart"`
	StartMinimized bool   `json:"startMinimized"`
	CloseToTray    bool   `json:"closeToTray"`
	HotkeyEnabled  bool   `json:"hotkeyEnabled"`
	LogLevel       string `json:"logLevel"` // trace|debug|info|warn
	ProxyPort      int    `json:"proxyPort"`
	StrictRoute    bool   `json:"strictRoute"`
	SelectedServer string `json:"selectedServer"`
	LastMode       string `json:"lastMode"`

	// --- продвинутые настройки ---
	AutoConnect   bool   `json:"autoConnect"`   // подключаться при запуске
	FastestServer bool   `json:"fastestServer"` // при подключении брать сервер с минимальным пингом
	CustomDNS     string `json:"customDNS"`     // свой DNS-адрес (пусто = пресет)
	BypassDomains string `json:"bypassDomains"` // домены/подсети, которые идут мимо VPN (через перенос)
	BlockAds      bool   `json:"blockAds"`      // блокировка рекламы и трекеров
	DisableIPv6   bool   `json:"disableIPv6"`   // не пускать IPv6 через туннель
	MTU           int    `json:"mtu"`           // MTU TUN-интерфейса (0 = 9000)
	UdpBlock      bool   `json:"udpBlock"`      // блокировать весь UDP мимо туннеля
}

// DefaultSettings — дефолтные настройки.
func DefaultSettings() Settings {
	return Settings{
		Mode:           "tun",
		KillSwitch:     false,
		BlockLAN:       false,
		BlockBT:        false,
		SetSystemProxy: false,
		DNS:            "auto",
		Autostart:      false,
		StartMinimized: false,
		CloseToTray:    true,
		HotkeyEnabled:  true,
		LogLevel:       "info",
		ProxyPort:      10808,
		StrictRoute:    true,
		MTU:            9000,
	}
}

// Status — статус подключения для UI.
type Status struct {
	Connected   bool   `json:"connected"`
	Connecting  bool   `json:"connecting"`
	Switching   bool   `json:"switching"` // идёт бесшовная смена сервера
	Mode        string `json:"mode"`
	ServerID    string `json:"serverId"`
	ServerName  string `json:"serverName"`
	Protocol    string `json:"protocol"`
	StartedAt   int64  `json:"startedAt"`
	Upload      int64  `json:"upload"`    // байт/с
	Download    int64  `json:"download"`  // байт/с
	UploadTot   int64  `json:"uploadTot"` // всего байт
	DownloadTot int64  `json:"downloadTot"`
	AssignedIP  string `json:"assignedIp"`
	ProxyAddr   string `json:"proxyAddr"` // адрес локального прокси (для режима proxy)
	Error       string `json:"error"`
}

// LogEntry — строка лога ядра.
type LogEntry struct {
	Time    string `json:"time"`
	Level   string `json:"level"`
	Message string `json:"message"`
}

// SpeedResult — результат теста скорости.
type SpeedResult struct {
	DownloadMbps float64 `json:"downloadMbps"`
	UploadMbps   float64 `json:"uploadMbps"`
	LatencyMs    int     `json:"latencyMs"`
	JitterMs     int     `json:"jitterMs"`
	MinMs        int     `json:"minMs"`
	MaxMs        int     `json:"maxMs"`
	URL          string  `json:"url"`
}

// LatencyResult — отдельный этап теста: задержка и её разброс.
type LatencyResult struct {
	AvgMs    int `json:"avgMs"`
	JitterMs int `json:"jitterMs"`
	MinMs    int `json:"minMs"`
	MaxMs    int `json:"maxMs"`
	Samples  int `json:"samples"`
}

// ImportResult — результат импорта.
type ImportResult struct {
	Added   int      `json:"added"`
	Skipped int      `json:"skipped"`
	Errors  []string `json:"errors"`
}
