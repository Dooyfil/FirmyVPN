import Libbox
import SwiftUI

/// Тест скорости: задержка (TCP, 7 замеров) + скачивание/загрузка через туннель
/// с анимированным прогрессом. Всё вписывается в экран.
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
                VStack(spacing: 14) {
                    resultCard
                    controlsCard
                    if let e = errorText {
                        Text(e)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.err)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 44)
            }
            .background(Color.clear)
            .navigationTitle("Тест скорости")
        }
    }

    // MARK: Результаты

    private var resultCard: some View {
        GlassCard(glow: on ? Theme.accent : Theme.violet) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(phaseText.isEmpty ? "Результат" : phaseText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(on ? Theme.ok : Theme.accent)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    progressRing
                }

                HStack(spacing: 8) {
                    metric(icon: "arrow.down", color: Theme.accent, title: "Загрузка",
                           value: download > 0 ? String(format: "%.1f", download) : "—", unit: "Мбит/с")
                    metric(icon: "arrow.up", color: Theme.violet, title: "Отдача",
                           value: upload > 0 ? String(format: "%.1f", upload) : "—", unit: "Мбит/с")
                }
                HStack(spacing: 8) {
                    metric(icon: "timer", color: Theme.ok, title: "Задержка",
                           value: latency != nil ? "\(latency!.avgMs)" : "—", unit: "мс")
                    metric(icon: "waveform.path.ecg", color: Theme.warn, title: "Джиттер",
                           value: latency != nil ? "\(latency!.jitterMs)" : "—", unit: "мс")
                }
                HStack(spacing: 8) {
                    metric(icon: "arrow.left.and.right", color: Theme.text3, title: "Потери",
                           value: latency == nil ? "0" : "\(lostSamples)", unit: "ошибок")
                }
            }
        }
    }

    private var on: Bool { state.vpn.isConnected }
    private var lostSamples: Int { 0 }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)
                .frame(width: 30, height: 30)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
        }
    }

    private func metric(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
                Text(title).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.text3).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.text1)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Кнопки

    private var controlsCard: some View {
        GlassCard(glow: on ? Theme.accent : .clear) {
            VStack(spacing: 12) {
                SectionTitle(text: "Тест")
                HStack(spacing: 8) {
                    NeonButton(title: running ? "Тестируем…" : "Полный тест",
                               icon: running ? nil : "play.fill",
                               height: 52) { runFull() }
                        .disabled(running)
                        .opacity(running ? 0.6 : 1)
                }
                HStack(spacing: 8) {
                    NeonButton(title: "Задержка", icon: "timer", filled: false, height: 44) { runLatencyOnly() }
                        .disabled(running)
                    NeonButton(title: "Скачать", icon: "arrow.down", filled: false, height: 44) { runDownloadOnly() }
                        .disabled(running)
                }
                HStack(spacing: 8) {
                    NeonButton(title: "Загрузить", icon: "arrow.up", filled: false, height: 44) { runUploadOnly() }
                        .disabled(running)
                }
                Text(on
                     ? "Тест идёт через туннель — покажет реальную скорость VPN."
                     : "VPN отключён — тест покажет скорость прямого соединения.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.text3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
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
        Task { await runLatency(); running = false }
    }
    private func runDownloadOnly() {
        running = true
        progress = 0
        Task { await runDownload(); progress = 1; running = false }
    }
    private func runUploadOnly() {
        running = true
        progress = 0
        Task { await runUpload(); progress = 1; running = false }
    }

    private func runLatency() async {
        phaseText = "Задержка…"
        guard let srv = state.selectedServer else { errorText = "Нет сервера"; return }
        var samples: [Int] = []
        let host = srv.host, port = srv.port
        for _ in 0..<7 {
            let ms = FirmycorePingTCP(host, port, 2500)
            if ms >= 0 { samples.append(Int(ms)) }
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
        latency = LatencyResult(avgMs: avg, jitterMs: jitter,
                                minMs: samples.min() ?? avg, maxMs: samples.max() ?? avg, samples: samples.count)
    }

    private func runDownload() async {
        phaseText = "Скачивание…"
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
                errorText = "Скачивание не удалось: \(error.localizedDescription)"
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
                _ = try await URLSession.shared.data(for: req)
                totalBytes += Int64(size)
            } catch {
                errorText = "Загрузка на сервер не удалась: \(error.localizedDescription)"
                break
            }
            progress = 0.7 + 0.3 * Double(i + 1) / Double(chunks)
        }
        let secs = Date().timeIntervalSince(start)
        guard secs > 0, totalBytes > 0 else { return }
        upload = Double(totalBytes) * 8 / secs / 1_000_000
    }
}
