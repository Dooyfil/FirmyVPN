import Libbox
import SwiftUI

/// Тест скорости: задержка (7 замеров через Go-ядро), скачивание и загрузка
/// через туннель с анимированным прогрессом.
struct SpeedTestView: View {
    @EnvironmentObject var state: AppState

    @State private var latency: LatencyResult?
    @State private var download: Double = 0   // Мбит/с
    @State private var upload: Double = 0
    @State private var progress: Double = 0   // 0…1
    @State private var running = false
    @State private var phaseText = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    resultCard
                    controlsCard
                    if let e = errorText {
                        Text(e)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.err)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.clear)
            .navigationTitle("Тест скорости")
        }
    }

    private var resultCard: some View {
        GlassCard(glow: Theme.accent) {
            VStack(spacing: 18) {
                // прогресс
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SectionTitle(text: running ? "Идёт тест" : "Результат")
                        Spacer()
                        Text(phaseText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Theme.neon)
                                .frame(width: geo.size.width * progress)
                                .shadow(color: Theme.accent.opacity(0.7), radius: 8)
                        }
                    }
                    .frame(height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)
                }

                VStack(spacing: 12) {
                    metric(icon: "arrow.down", color: Theme.accent, title: "Загрузка",
                           value: download > 0 ? String(format: "%.1f", download) : "—", unit: "Мбит/с")
                    metric(icon: "arrow.up", color: Theme.violet, title: "Отдача",
                           value: upload > 0 ? String(format: "%.1f", upload) : "—", unit: "Мбит/с")
                }
                VStack(spacing: 12) {
                    metric(icon: "timer", color: Theme.ok, title: "Задержка",
                           value: latency != nil ? "\(latency!.avgMs)" : "—", unit: "мс")
                    metric(icon: "waveform.path.ecg", color: Theme.warn, title: "Джиттер",
                           value: latency != nil ? "\(latency!.jitterMs)" : "—", unit: "мс")
                }
            }
        }
    }

    private func metric(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
                Text(title).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.text3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text1)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var controlsCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                NeonButton(title: running ? "Тест выполняется…" : "Запустить полный тест",
                           icon: running ? nil : "play.fill") {
                    runFull()
                }
                .disabled(running)
                .opacity(running ? 0.6 : 1)

                HStack(spacing: 10) {
                    NeonButton(title: "Задержка", icon: "timer", filled: false) { runLatencyOnly() }
                        .disabled(running)
                    NeonButton(title: "Скачать", icon: "arrow.down", filled: false) { runDownloadOnly() }
                        .disabled(running)
                }
                NeonButton(title: "Загрузить", icon: "arrow.up", filled: false) { runUploadOnly() }
                    .disabled(running)
                Text(state.vpn.isConnected
                     ? "Тест идёт через туннель: покажет реальную скорость VPN."
                     : "VPN отключён — тест покажет скорость прямого соединения.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.text3)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Прогоны

    private func runFull() {
        errorText = nil
        running = true
        progress = 0
        Task {
            await runLatency()
            progress = 0.25
            await runDownload()
            progress = 0.7
            await runUpload()
            progress = 1
            phaseText = "Готово"
            running = false
        }
    }

    private func runLatencyOnly() {
        running = true
        Task {
            await runLatency()
            running = false
        }
    }

    private func runDownloadOnly() {
        running = true
        progress = 0
        Task {
            await runDownload()
            progress = 1
            running = false
        }
    }

    private func runUploadOnly() {
        running = true
        progress = 0
        Task {
            await runUpload()
            progress = 1
            running = false
        }
    }

    private func runLatency() async {
        phaseText = "Задержка…"
        guard let srv = state.selectedServer else { errorText = "Нет сервера"; return }
        var samples: [Int] = []
        let host = srv.host, port = srv.port
        for _ in 0..<7 {
            let ms = Int(FirmycorePingTCP(host, port, 2500))
            if ms >= 0 { samples.append(ms) }
            try? await Task.sleep(nanoseconds: 180_000_000)
        }
        guard !samples.isEmpty else {
            errorText = "Сервер не отвечает на TCP-подключение"
            latency = LatencyResult(avgMs: -1, jitterMs: 0, minMs: -1, maxMs: -1, samples: 0)
            return
        }
        let avg = samples.reduce(0, +) / samples.count
        var jitter = 0
        if samples.count > 1 {
            var sum = 0
            for i in 1..<samples.count { sum += abs(samples[i] - samples[i - 1]) }
            jitter = sum / (samples.count - 1)
        }
        latency = LatencyResult(avgMs: avg,
                                jitterMs: jitter,
                                minMs: samples.min() ?? avg,
                                maxMs: samples.max() ?? avg,
                                samples: samples.count)
    }

    private func runDownload() async {
        phaseText = "Загрузка…"
        errorText = nil
        let chunks = 5
        let size = 5 * 1024 * 1024
        var totalBytes: Int64 = 0
        let start = Date()
        for i in 0..<chunks {
            guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(size)") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                totalBytes += Int64(data.count)
            } catch {
                errorText = "Загрузка не удалась: \(error.localizedDescription)"
                break
            }
            progress = 0.25 + 0.45 * Double(i + 1) / Double(chunks)
        }
        let secs = Date().timeIntervalSince(start)
        guard secs > 0, totalBytes > 0 else { return }
        download = Double(totalBytes) * 8 / secs / 1_000_000
    }

    private func runUpload() async {
        phaseText = "Загрузка на сервер…"
        errorText = nil
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return }
        let chunks = 4
        let size = 1024 * 1024
        var totalBytes: Int64 = 0
        let start = Date()
        for i in 0..<chunks {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 30
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data(repeating: 0x5A, count: size)
            do {
                let (_, _) = try await URLSession.shared.data(for: req)
                totalBytes += Int64(size)
            } catch {
                errorText = "Загрузка не удалась: \(error.localizedDescription)"
                break
            }
            progress = 0.7 + 0.3 * Double(i + 1) / Double(chunks)
        }
        let secs = Date().timeIntervalSince(start)
        guard secs > 0, totalBytes > 0 else { return }
        upload = Double(totalBytes) * 8 / secs / 1_000_000
    }
}
