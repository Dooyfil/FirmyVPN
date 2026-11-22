import Foundation

// MARK: - JSON (вход/выход Go-ядра)

/// Произвольный JSON: outbound сервера приходит из Go как сырой объект.
enum JSONValue: Codable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.string(let a), .string(let b)): return a == b
        case (.array(let a), .array(let b)):
            return a.count == b.count && zip(a, b).allSatisfy { $0 == $1 }
        case (.object(let a), .object(let b)):
            return a.keys.count == b.keys.count && a.allSatisfy { k, v in
                (b[k]).map { $0 == v } ?? false
            }
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .null: hasher.combine("null")
        case .bool(let v): hasher.combine("bool"); hasher.combine(v)
        case .number(let v): hasher.combine("number"); hasher.combine(v)
        case .string(let v): hasher.combine("string"); hasher.combine(v)
        case .array(let v): hasher.combine("array"); hasher.combine(v.count); v.forEach { $0.hash(into: &hasher) }
        case .object(let v): hasher.combine("object"); hasher.combine(v.keys.count); v.forEach { k, val in hasher.combine(k); val.hash(into: &hasher) }
        }
    }
}

// MARK: - Сервер

/// Один сервер/ключ — форма JSON совпадает с model.Server в Go-ядре.
struct Server: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    var name: String = ""
    var protocolName: String = ""
    var type: String = ""
    var host: String = ""
    var port: Int = 0
    var uri: String = ""
    var outbound: JSONValue = .object([:])
    var source: String = "manual"          // manual | subscription | file
    var subUrl: String?
    var subName: String?
    var addedAt: Int64 = Int64(Date().timeIntervalSince1970)
    var ping: Int = -1                     // мс; -1 = неизвестно

    enum CodingKeys: String, CodingKey {
        case id, name, type, host, port, uri, outbound, source, subUrl, subName, addedAt, ping
        case protocolName = "protocol"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        protocolName = try c.decodeIfPresent(String.self, forKey: .protocolName) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 0
        uri = try c.decodeIfPresent(String.self, forKey: .uri) ?? ""
        outbound = try c.decodeIfPresent(JSONValue.self, forKey: .outbound) ?? .object([:])
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "manual"
        subUrl = try c.decodeIfPresent(String.self, forKey: .subUrl)
        subName = try c.decodeIfPresent(String.self, forKey: .subName)
        addedAt = try c.decodeIfPresent(Int64.self, forKey: .addedAt) ?? Int64(Date().timeIntervalSince1970)
        ping = try c.decodeIfPresent(Int.self, forKey: .ping) ?? -1
    }

    var title: String { name.isEmpty ? "\(protocolName) \(host):\(port)" : name }
    var protocolShort: String { protocolName.uppercased() }
}

// MARK: - Настройки

/// Настройки — поля и JSON-ключи совпадают с model.Settings в Go-ядре.
struct AppSettings: Codable {
    var mode = "tun"                 // на iOS всегда tun
    var killSwitch = false           // → NETunnelProviderProtocol.includeAllNetworks
    var blockLan = false
    var blockBt = false
    var setSystemProxy = false       // на iOS не применяется
    var dns = "auto"                 // auto | cloudflare | quad9 | adguard | direct
    var autostart = false
    var startMinimized = false
    var closeToTray = true
    var hotkeyEnabled = true
    var logLevel = "info"
    var proxyPort = 10808
    var strictRoute = true
    var selectedServer = ""
    var lastMode = ""
    var autoConnect = false
    var fastestServer = false
    var customDNS = ""
    var bypassDomains = ""
    var blockAds = false
    var disableIPv6 = false
    var mtu = 9000
    var udpBlock = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? "tun"
        killSwitch = try c.decodeIfPresent(Bool.self, forKey: .killSwitch) ?? false
        blockLan = try c.decodeIfPresent(Bool.self, forKey: .blockLan) ?? false
        blockBt = try c.decodeIfPresent(Bool.self, forKey: .blockBt) ?? false
        setSystemProxy = try c.decodeIfPresent(Bool.self, forKey: .setSystemProxy) ?? false
        dns = try c.decodeIfPresent(String.self, forKey: .dns) ?? "auto"
        autostart = try c.decodeIfPresent(Bool.self, forKey: .autostart) ?? false
        startMinimized = try c.decodeIfPresent(Bool.self, forKey: .startMinimized) ?? false
        closeToTray = try c.decodeIfPresent(Bool.self, forKey: .closeToTray) ?? true
        hotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        logLevel = try c.decodeIfPresent(String.self, forKey: .logLevel) ?? "info"
        proxyPort = try c.decodeIfPresent(Int.self, forKey: .proxyPort) ?? 10808
        strictRoute = try c.decodeIfPresent(Bool.self, forKey: .strictRoute) ?? true
        selectedServer = try c.decodeIfPresent(String.self, forKey: .selectedServer) ?? ""
        lastMode = try c.decodeIfPresent(String.self, forKey: .lastMode) ?? ""
        autoConnect = try c.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? false
        fastestServer = try c.decodeIfPresent(Bool.self, forKey: .fastestServer) ?? false
        customDNS = try c.decodeIfPresent(String.self, forKey: .customDNS) ?? ""
        bypassDomains = try c.decodeIfPresent(String.self, forKey: .bypassDomains) ?? ""
        blockAds = try c.decodeIfPresent(Bool.self, forKey: .blockAds) ?? false
        disableIPv6 = try c.decodeIfPresent(Bool.self, forKey: .disableIPv6) ?? false
        mtu = try c.decodeIfPresent(Int.self, forKey: .mtu) ?? 9000
        udpBlock = try c.decodeIfPresent(Bool.self, forKey: .udpBlock) ?? false
    }
}

// MARK: - Результат импорта

struct ImportResult: Codable {
    var servers: [Server] = []
    var errors: [String] = []
}

// MARK: - Статистика трафика

struct TrafficStats: Codable {
    var upSpeed: Int64 = 0     // байт/с
    var downSpeed: Int64 = 0
    var upTot: Int64 = 0       // всего байт
    var downTot: Int64 = 0
}

// MARK: - Тест задержки

struct LatencyResult: Codable {
    var avgMs: Int = -1
    var jitterMs: Int = 0
    var minMs: Int = -1
    var maxMs: Int = -1
    var samples: Int = 0
}

// MARK: - Статус

enum TunnelPhase: String {
    case disconnected, connecting, connected, switching, error

    var label: String {
        switch self {
        case .disconnected: return "Отключено"
        case .connecting: return "Подключение…"
        case .connected: return "Защищено"
        case .switching: return "Смена сервера…"
        case .error: return "Ошибка"
        }
    }
}
