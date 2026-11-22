import Foundation
import NetworkExtension

/// Системный профиль VPN («FirmyVPN» в Настройках → VPN) и кнопка подключения.
/// Kill switch → `includeAllNetworks`: ничего не уходит мимо туннеля.
@MainActor
final class VPNController: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    @Published var lastError: String?
    @Published var connectedSince: Date?
    @Published var stats = TrafficStats()

    static let extensionBundleID: String =
        (Bundle.main.bundleIdentifier ?? "com.firmyvpn.app") + ".PacketTunnel"

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    var isOn: Bool { status == .connected || status == .connecting || status == .reasserting }
    var isConnected: Bool { status == .connected }

    // MARK: Загрузка профиля

    func prepare() async {
        let all = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        manager = all.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.extensionBundleID
        }
        observe()
        status = manager?.connection.status ?? .invalid
        if status == .connected { connectedSince = connectedSince ?? Date() }
    }

    private func observe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: manager?.connection, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let s = (note.object as? NEVPNConnection)?.status ?? .invalid
            Task { @MainActor in self.apply(s) }
        }
    }

    private func apply(_ s: NEVPNStatus) {
        let was = status
        status = s
        switch s {
        case .connected:
            if was != .connected { connectedSince = Date() }
            lastError = nil
        case .disconnected, .invalid:
            if was == .connected || was == .connecting { connectedSince = nil }
            stats = TrafficStats()
            // расширение пишет причину сюда при неудачном старте
            if s == .disconnected,
               let e = try? String(contentsOf: AppGroup.lastErrorURL, encoding: .utf8),
               !e.isEmpty {
                lastError = String(e.prefix(1800))
            }
        default:
            break
        }
    }

    // MARK: Подключение

    /// Пишет настройки/сервер в общую папку и VPN-профиль, затем стартует
    /// туннель (или, если уже подключено — бесшовно перезагружает ядро).
    func connect(settings: AppSettings, server: Server) async throws {
        SettingsFile.save(settings)
        let serverData = try JSONEncoder().encode(server)
        let settingsData = try JSONEncoder().encode(settings)

        if let m = manager, m.connection.status == .connected || m.connection.status == .connecting {
            // бесшовная смена сервера: ядро подхватит новые файлы по "reload"
            _ = await send("reload")
            return
        }

        let m = try await ensureManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Self.extensionBundleID
        proto.serverAddress = server.host.isEmpty ? "FirmyVPN" : server.host
        proto.serverPort = Int32(server.port)
        proto.includeAllNetworks = settings.killSwitch
        // LAN должен работать мимо VPN, только если пользователь не просил блокировать
        proto.excludeLocalNetworks = !settings.blockLan
        if #available(iOS 16.4, *) {
            // При kill switch'е пуш-уведомления и сотовые службы всё равно работают
            proto.excludeCellularServices = true
            proto.excludeAPNs = true
        }
        if #available(iOS 17.4, *) { proto.excludeDeviceCommunication = true }
        proto.enforceRoutes = false
        proto.disconnectOnSleep = false
        proto.providerConfiguration = [
            "settings": settingsData,
            "server": serverData,
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        ]
        m.protocolConfiguration = proto
        m.localizedDescription = "FirmyVPN"
        m.isEnabled = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences() // без повторной загрузки первый старт падает
        manager = m
        lastError = nil
        try m.connection.startVPNTunnel()
        status = m.connection.status
    }

    func disconnect() async {
        manager?.connection.stopVPNTunnel()
    }

    /// Настройки изменились: обновить их копию в профиле VPN (на случай,
    /// если общая папка недоступна) и перезагрузить ядро без разрыва туннеля.
    func settingsChanged(settings: AppSettings, server: Server?) async {
        guard let m = manager, let p = m.protocolConfiguration as? NETunnelProviderProtocol else { return }
        var cfg = p.providerConfiguration ?? [:]
        if let sData = try? JSONEncoder().encode(settings) { cfg["settings"] = sData }
        if let server, let svData = try? JSONEncoder().encode(server) { cfg["server"] = svData }
        p.providerConfiguration = cfg
        try? await m.saveToPreferences()
        if m.connection.status == .connected || m.connection.status == .reasserting {
            _ = await send("reload")
        }
    }

    private func ensureManager() async throws -> NETunnelProviderManager {
        if let m = manager { return m }
        let m = NETunnelProviderManager()
        manager = m
        observe()
        return m
    }

    // MARK: Сообщения расширению

    func send(_ message: String) async -> Data? {
        guard let session = manager?.connection as? NETunnelProviderSession,
              session.status == .connected || session.status == .reasserting else { return nil }
        return await withCheckedContinuation { cont in
            do {
                try session.sendProviderMessage(Data(message.utf8)) { data in
                    cont.resume(returning: data)
                }
            } catch {
                cont.resume(returning: nil)
            }
        }
    }

    /// Опрос статистики раз в секунду (из clash API внутри расширения).
    func pollStats() async {
        guard let data = await send("stats"),
              let s = try? JSONDecoder().decode(TrafficStats.self, from: data) else { return }
        stats = s
    }

    func requestLog() async -> String {
        guard let data = await send("log") else {
            // без сообщений — читаем общий файл сами
            return SharedLog.tail(maxBytes: 40_000).map { "[\($0.source)] \($0.text)" }.joined(separator: "\n")
        }
        return String(decoding: data, as: UTF8.self)
    }
}
