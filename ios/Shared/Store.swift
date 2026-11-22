import Foundation

// MARK: - App Group

/// Папка, общая для приложения и Packet Tunnel. Если профиль подписи не даёт
/// группу (переподпись чужим сертификатом), берём первую рабочую группу профиля,
/// а при её отсутствии — общие файлы в профиле VPN (providerConfiguration).
enum AppGroup {
    static let declaredID: String =
        Bundle.main.object(forInfoDictionaryKey: "FirmyAppGroup") as? String ?? "group.com.firmyvpn.app"

    static let id: String = {
        #if os(iOS)
        let fm = FileManager.default
        if fm.containerURL(forSecurityApplicationGroupIdentifier: declaredID) != nil { return declaredID }
        for g in profileGroups() where fm.containerURL(forSecurityApplicationGroupIdentifier: g) != nil {
            return g
        }
        #endif
        return declaredID
    }()

    static var isShared: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    /// Общая папка, а если её нет — своя во временном каталоге (тогда настройки
    /// едут в providerConfiguration профиля VPN).
    static let container: URL = {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FirmyVPN", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var workingDir: URL { dir("working") }
    static var tempDir: URL { dir("temp") }

    private static func dir(_ name: String) -> URL {
        let url = container.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var settingsURL: URL { container.appendingPathComponent("settings.json") }
    static var serversURL: URL { container.appendingPathComponent("servers.json") }
    static var logURL: URL { container.appendingPathComponent("log.txt") }
    static var lastErrorURL: URL { container.appendingPathComponent("last-error.txt") }
    static var lastConfigURL: URL { container.appendingPathComponent("last-config.json") }

    /// App Groups из embedded.mobileprovision приложения (расширение смотрит в
    /// приложение, которое его содержит) — для переподписанных сборок.
    private static func profileGroups() -> [String] {
        var bundle = Bundle.main.bundleURL
        if bundle.pathExtension == "appex" {
            bundle = bundle.deletingLastPathComponent().deletingLastPathComponent()
        }
        guard let data = try? Data(contentsOf: bundle.appendingPathComponent("embedded.mobileprovision")),
              let xml = String(data: data, encoding: .isoLatin1),
              let start = xml.range(of: "<?xml"),
              let end = xml.range(of: "</plist>"),
              let plistData = xml[start.lowerBound..<end.upperBound].data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let groups = plist["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }
}

// MARK: - Настройки и серверы

enum SettingsFile {
    static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: AppGroup.settingsURL),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    static func save(_ s: AppSettings) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: AppGroup.settingsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum ServersFile {
    static func load() -> [Server] {
        guard let data = try? Data(contentsOf: AppGroup.serversURL),
              let list = try? JSONDecoder().decode([Server].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [Server]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: AppGroup.serversURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

// MARK: - Журнал

/// Общий журнал приложения и расширения: строки "время\tисточник\tтекст".
enum SharedLog {
    static func append(_ source: String, _ text: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "\(ts)\t\(source)\t\(text.replacingOccurrences(of: "\n", with: " "))\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = AppGroup.logURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url, options: .atomic)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        trim()
    }

    static func tail(maxBytes: Int = 60_000) -> [(time: String, source: String, text: String)] {
        guard let data = try? Data(contentsOf: AppGroup.logURL) else { return [] }
        var bytes = data
        if bytes.count > maxBytes { bytes = bytes.suffix(maxBytes) }
        guard let text = String(data: bytes, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { return nil }
            return (String(parts[0]), String(parts[1]), String(parts[2]))
        }
    }

    static func clear() {
        try? Data().write(to: AppGroup.logURL, options: .atomic)
    }

    static func trim(maxBytes: Int = 400_000) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: AppGroup.logURL.path),
              let size = attrs[.size] as? Int, size > maxBytes else { return }
        guard let data = try? Data(contentsOf: AppGroup.logURL) else { return }
        let cut = data.suffix(maxBytes)
        guard let text = String(data: cut, encoding: .utf8),
              let nl = text.firstIndex(of: "\n") else { return }
        try? Data(text[text.index(after: nl)...].utf8).write(to: AppGroup.logURL, options: .atomic)
    }
}
