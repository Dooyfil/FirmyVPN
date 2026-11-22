import Foundation
import Libbox
import NetworkExtension
import os

/// Сам VPN: sing-box (libbox) внутри Network Extension. Жизненный цикл — по образцу
/// sing-box for Apple (GPL-3.0): конфиг собирается здесь из общей папки/профиля,
/// а не передаётся приложением: Connect On Demand стартует туннель и без приложения.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = Logger(subsystem: "com.firmyvpn.app", category: "tunnel")
    private var commandServer: LibboxCommandServer?
    private var platform: ExtensionPlatformInterface?
    private var statsTimer: DispatchSourceTimer?
    private var statsReply: Data = Data()
    private var lastTotals: (up: Int64, down: Int64, at: Date)?

    /// Старт/стоп/перезагрузка — никогда на очереди, которой зовёт система:
    /// sing-box ждёт внутри них ответа setTunnelNetworkSettings (openTun), а он
    /// приходит на системной очереди — блокировка зависает до убийства расширения.
    private let work = DispatchQueue(label: "firmyvpn.tunnel")

    override func startTunnel(options: [String: NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        work.async { self.start(completionHandler) }
    }

    private func start(_ completionHandler: @escaping (Error?) -> Void) {
        do {
            try? FileManager.default.removeItem(at: AppGroup.lastErrorURL)
            let groupState = AppGroup.isShared ? "общая" : "нет (настройки из профиля VPN)"
            SharedLog.append("tunnel", "start: App Group \(groupState)")
            try setupLibbox()
            let (serverJSON, settingsJSON) = try loadInputs()
            let config = try buildConfig(serverJSON: serverJSON, settingsJSON: settingsJSON)
            SharedLog.append("tunnel", "config: \(config.utf8.count) байт")

            let platform = ExtensionPlatformInterface(self)
            self.platform = platform
            var error: NSError?
            guard let cmd = LibboxNewCommandServer(self, platform, &error) else {
                throw error ?? fail("libbox: command server")
            }
            try cmd.start()
            commandServer = cmd
            try cmd.startOrReloadService(config, options: LibboxOverrideOptions())
            startStats()
            SharedLog.append("tunnel", "ядро запущено")
            completionHandler(nil)
        } catch {
            SharedLog.append("error", error.localizedDescription)
            try? Data(error.localizedDescription.utf8).write(to: AppGroup.lastErrorURL, options: .atomic)
            stopLibbox()
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        work.async {
            SharedLog.append("tunnel", "stop: \(reason.rawValue)")
            self.stopLibbox()
            completionHandler()
        }
    }

    // MARK: Сообщения от приложения

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        switch String(decoding: messageData, as: UTF8.self) {
        case "stats":
            completionHandler?(statsReply)
        case "reload":
            work.async {
                do {
                    try self.reload()
                    completionHandler?(Data("ok".utf8))
                } catch {
                    completionHandler?(Data(error.localizedDescription.utf8))
                }
            }
        case "log":
            let text = SharedLog.tail(maxBytes: 40_000)
                .map { "\($0.time)\t\($0.source)\t\($0.text)" }
                .joined(separator: "\n")
            completionHandler?(Data(text.utf8))
        case "clear-log":
            SharedLog.clear()
            completionHandler?(Data("ok".utf8))
        default:
            completionHandler?(nil)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        commandServer?.pause()
        completionHandler()
    }

    override func wake() {
        commandServer?.wake()
    }

    // MARK: libbox

    private static var setupDone = false

    private func setupLibbox() throws {
        guard !Self.setupDone else { return }
        let o = LibboxSetupOptions()
        o.basePath = AppGroup.container.path
        o.workingPath = AppGroup.workingDir.path
        o.tempPath = AppGroup.tempDir.path
        o.logMaxLines = 2000
        // Сокет командного сервера — <basePath>/command.sock, а путь Unix-сокета
        // длиннее 103 байт не бывает. Папка App Group влезает; своя папка
        // переподписанного расширения — нет, там берём loopback TCP.
        if o.basePath.utf8.count + "/command.sock".utf8.count > 103 {
            o.commandServerListenPort = 19091
        }
        // iOS убивает расширение выше ~50 МБ: держим кучу Go под лимитом.
        o.oomKillerEnabled = true
        o.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        o.appMarketingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        var error: NSError?
        LibboxSetup(o, &error)
        if let error { throw error }
        Self.setupDone = true
    }

    /// JSON сервера и настроек: из общей папки, а без App Group — из
    /// providerConfiguration профиля VPN (его пишет приложение при подключении).
    private func loadInputs() throws -> (String, String) {
        var settingsData: Data?
        var serverData: Data?

        if AppGroup.isShared,
           let sdata = try? Data(contentsOf: AppGroup.serversURL),
           let servers = try? JSONDecoder().decode([Server].self, from: sdata) {
            let settings = SettingsFile.load()
            let active = servers.first { $0.id == settings.selectedServer } ?? servers.first
            if let active, let encoded = try? JSONEncoder().encode(active) {
                serverData = encoded
                settingsData = try? JSONEncoder().encode(settings)
            }
        }

        if settingsData == nil || serverData == nil {
            let stored = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration
            if settingsData == nil { settingsData = stored?["settings"] as? Data }
            if serverData == nil { serverData = stored?["server"] as? Data }
        }

        guard let sd = settingsData, let srvd = serverData,
              let sj = String(data: sd, encoding: .utf8),
              let rj = String(data: srvd, encoding: .utf8)
        else { throw fail("Нет сервера: добавьте его в приложении FirmyVPN.") }
        return (rj, sj)
    }

    private func buildConfig(serverJSON: String, settingsJSON: String) throws -> String {
        var error: NSError?
        guard let config = FirmycoreBuildConfigJSON(serverJSON, settingsJSON, AppGroup.container.path, &error)
        else { throw error ?? fail("сборка конфига") }
        try? Data(config.utf8).write(to: AppGroup.lastConfigURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return config
    }

    private func reload() throws {
        guard let cmd = commandServer else { return }
        let (serverJSON, settingsJSON) = try loadInputs()
        let config = try buildConfig(serverJSON: serverJSON, settingsJSON: settingsJSON)
        try cmd.startOrReloadService(config, options: LibboxOverrideOptions())
        SharedLog.append("tunnel", "конфиг перезагружен")
    }

    private func stopLibbox() {
        statsTimer?.cancel()
        statsTimer = nil
        try? commandServer?.closeService()
        commandServer?.close()
        commandServer = nil
        platform?.reset()
        platform = nil
        lastTotals = nil
        statsReply = Data()
    }

    // MARK: Статистика (clash API внутри расширения)

    private func startStats() {
        let t = DispatchSource.makeTimerSource(queue: work)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in self?.pollClash() }
        t.resume()
        statsTimer = t
    }

    private func pollClash() {
        guard let url = URL(string: "http://127.0.0.1:9097/connections") else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let up = Int64(obj["uploadTotal"] as? Double ?? 0)
            let down = Int64(obj["downloadTotal"] as? Double ?? 0)
            self.work.async {
                let now = Date()
                var upSpeed: Int64 = 0, downSpeed: Int64 = 0
                if let last = self.lastTotals {
                    let dt = now.timeIntervalSince(last.at)
                    if dt > 0.4 {
                        upSpeed = Int64(Double(up - last.up) / dt)
                        downSpeed = Int64(Double(down - last.down) / dt)
                    }
                }
                self.lastTotals = (up, down, now)
                let stats = TrafficStats(upSpeed: max(0, upSpeed), downSpeed: max(0, downSpeed),
                                         upTot: up, downTot: down)
                self.statsReply = (try? JSONEncoder().encode(stats)) ?? Data()
            }
        }
        task.resume()
    }

    func fail(_ message: String) -> NSError {
        NSError(domain: "FirmyVPN", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - LibboxCommandServerHandler

extension PacketTunnelProvider: LibboxCommandServerHandlerProtocol {
    func serviceStop() throws {
        cancelTunnelWithError(nil)
    }

    func serviceReload() throws {
        try reload()
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let st = LibboxSystemProxyStatus()
        st.available = false
        st.enabled = false
        return st
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {}

    func triggerNativeCrash() throws {}

    func writeDebugMessage(_ message: String?) {
        if let message { log.debug("\(message, privacy: .public)") }
    }

    func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw fail("not supported")
    }
}
