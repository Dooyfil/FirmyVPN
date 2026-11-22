import Foundation
import Libbox
import SwiftUI

/// Состояние приложения: серверы, настройки, импорт, пинг, статус туннеля.
@MainActor
final class AppState: ObservableObject {
    @Published var settings = SettingsFile.load()
    @Published var servers: [Server] = ServersFile.load()
    @Published var phase: TunnelPhase = .disconnected
    @Published var stats = TrafficStats()
    @Published var lastError: String?
    @Published var importBanner: String?
    @Published var logs: [(time: String, source: String, text: String)] = []

    let vpn = VPNController()
    private var timer: Timer?
    private var reloadTask: Task<Void, Never>?

    init() {
        if settings.selectedServer.isEmpty || !servers.contains(where: { $0.id == settings.selectedServer }) {
            settings.selectedServer = servers.first?.id ?? ""
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    // MARK: Серверы

    var selectedServer: Server? {
        servers.first { $0.id == settings.selectedServer } ?? servers.first
    }

    func select(_ s: Server) {
        settings.selectedServer = s.id
        save()
        if vpn.isConnected || vpn.status == .connecting {
            phase = .switching
        }
    }

    func save() {
        SettingsFile.save(settings)
        ServersFile.save(servers)
        // перезагрузка ядра — не чаще раза в 0.6 с (правки текста подряд)
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !Task.isCancelled else { return }
            guard self.vpn.isConnected || self.vpn.status == .connecting else { return }
            await self.vpn.settingsChanged(settings: self.settings, server: self.selectedServer)
        }
    }

    // MARK: Подключение

    func toggle() {
        Task {
            if vpn.isOn {
                phase = .disconnected
                lastError = nil
                await vpn.disconnect()
            } else {
                await connect()
            }
        }
    }

    func connect() async {
        guard var srv = selectedServer else {
            lastError = "Нет сервера: добавьте его во вкладке «Серверы»"
            phase = .error
            return
        }
        phase = vpn.isConnected ? .switching : .connecting
        lastError = nil

        // «самый быстрый» — пингуем всё и берём минимальный
        if settings.fastestServer && servers.count > 1 {
            await pingAll()
            if let best = servers.filter({ $0.ping >= 0 }).min(by: { $0.ping < $1.ping }) {
                srv = best
                settings.selectedServer = best.id
            }
        }
        SettingsFile.save(settings)

        do {
            try await vpn.connect(settings: settings, server: srv)
            SharedLog.append("app", "подключение к \(srv.title)")
        } catch {
            lastError = error.localizedDescription
            phase = .error
            SharedLog.append("app", "ошибка: \(error.localizedDescription)")
        }
    }

    /// Бесшовная смена сервера во время работы.
    func switchTo(_ s: Server) {
        select(s)
        guard vpn.isConnected else {
            if vpn.status != .connecting { Task { await connect() } }
            return
        }
        Task { _ = await vpn.send("reload") }
    }

    // MARK: Пинг

    func ping(_ s: Server, done: @escaping (Int) -> Void) {
        let host = s.host, port = s.port
        DispatchQueue.global(qos: .userInitiated).async {
            let ms = Int(FirmycorePingTCP(host, port, 3000))
            DispatchQueue.main.async { done(ms) }
        }
    }

    func ping(_ index: Int) {
        guard servers.indices.contains(index) else { return }
        let id = servers[index].id
        ping(servers[index]) { [weak self] ms in
            guard let self, let i = self.servers.firstIndex(where: { $0.id == id }) else { return }
            self.servers[i].ping = ms
            ServersFile.save(self.servers)
        }
    }

    func pingAll() async {
        await withTaskGroup(of: Void.self) { group in
            for i in servers.indices {
                group.addTask { @MainActor in self.ping(i) }
            }
        }
        // даём ответам прийти
        try? await Task.sleep(nanoseconds: 3_500_000_000)
    }

    // MARK: Импорт

    /// Разбор текста (ссылки/base64/JSON/YAML) через Go-ядро; дубли пропускаются.
    func importText(_ text: String, source: String, subURL: String = "", subName: String = "") -> ImportResult? {
        var error: NSError?
        let json = FirmycoreParseInputJSON(text, source, subURL, subName, &error)
        guard !json.isEmpty else {
            importBanner = error?.localizedDescription ?? "Не удалось разобрать ввод"
            return nil
        }
        let res: ImportResult
        do {
            res = try JSONDecoder().decode(ImportResult.self, from: Data(json.utf8))
        } catch {
            importBanner = "Ошибка разбора результата: \(error.localizedDescription)"
            return nil
        }

        var added = 0
        for s in res.servers where !contains(s) {
            servers.append(s)
            added += 1
        }
        ServersFile.save(servers)
        if settings.selectedServer.isEmpty { settings.selectedServer = servers.first?.id ?? "" }

        var errs = res.errors
        if added == 0 && errs.isEmpty { errs = ["Ничего не найдено (возможно, это не ключ/подписка)"] }
        importBanner = added > 0
            ? "Добавлено серверов: \(added)" + (errs.isEmpty ? "" : " · замечаний: \(errs.count)")
            : (errs.first ?? "Ничего не добавлено")
        SharedLog.append("import", "добавлено \(added), ошибок \(errs.count)")
        return ImportResult(servers: Array(servers.suffix(added)), errors: errs)
    }

    private func contains(_ s: Server) -> Bool {
        let key = s.uri.isEmpty ? "\(s.protocolName)|\(s.host)|\(s.port)|\(s.name)" : s.uri
        return servers.contains {
            let k = $0.uri.isEmpty ? "\($0.protocolName)|\($0.host)|\($0.port)|\($0.name)" : $0.uri
            return k == key
        }
    }

    /// Загрузка подписки по URL: base64 или обычный текст ключей.
    func fetchSubscription(_ url: String, name: String) async -> String? {
        guard let u = URL(string: url.trimmingCharacters(in: .whitespaces)), u.scheme?.hasPrefix("http") == true else {
            return "Неверный адрес подписки"
        }
        var req = URLRequest(url: u)
        req.timeoutInterval = 30
        req.setValue("FirmyVPN/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return "Сервер ответил HTTP \(http.statusCode)"
            }
            var text = String(data: data, encoding: .utf8) ?? ""
            // подписка может прийти в base64
            if !text.contains("://"), !text.contains("proxies"), let decoded = decodeBase64(text) {
                text = decoded
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Пустая подписка"
            }
            if importText(text, source: "subscription", subURL: url, subName: name) != nil {
                return nil
            }
            return importBanner ?? "Не удалось разобрать подписку"
        } catch {
            return "Ошибка загрузки: \(error.localizedDescription)"
        }
    }

    private func decodeBase64(_ s: String) -> String? {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        guard let data = Data(base64Encoded: t, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Журнал

    func refreshLogs() {
        logs = SharedLog.tail(maxBytes: 40_000)
    }

    func clearLogs() {
        SharedLog.clear()
        logs = []
    }

    // MARK: Тик раз в секунду

    private func tick() async {
        switch vpn.status {
        case .connected:
            phase = .connected
        case .connecting, .reasserting:
            if phase != .switching { phase = .connecting }
        default:
            if phase != .error { phase = .disconnected }
        }
        lastError = vpn.lastError ?? lastError
        if vpn.isOn {
            await vpn.pollStats()
            stats = vpn.stats
        }
    }
}
