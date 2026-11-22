import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var vpn: VPNController
    var onOpenServers: () -> Void = {}
    var onOpenSpeed: () -> Void = {}

    @State private var showLog = false
    @State private var pulseTitle = false

    private var busy: Bool { state.phase == .connecting || state.phase == .switching }
    private var on: Bool { state.phase == .connected }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    PowerButton(isOn: on, busy: busy) { state.toggle() }
                        .padding(.top, 6)
                    statusBlock
                    if !on && !busy { serverCard }
                    if on { trafficCard }
                    if let since = vpn.connectedSince, on { sessionCard(since) }
                    quickActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.clear)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLog = true } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(Theme.text2)
                    }
                }
            }
            .sheet(isPresented: $showLog) { LogsView() }
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.neon)
                    .frame(width: 44, height: 44)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 14, y: 6)
                Image(systemName: "shield.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("FirmyVPN")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text1)
                    .lineLimit(1)
                Text("безопасный туннель")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
    }

    private var pillColor: Color {
        switch state.phase {
        case .connected: return Theme.ok
        case .connecting, .switching: return Theme.warn
        case .error: return Theme.err
        case .disconnected: return Theme.text3
        }
    }

    // MARK: Статус

    private var statusBlock: some View {
        HStack(spacing: 8) {
            VStack(spacing: 8) {
                Text(state.phase.label)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(on ? Theme.ok : Theme.text1)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: state.phase)

                if let err = state.lastError, state.phase == .error {
                    Text(err)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.err)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                if let srv = state.selectedServer, !on {
                    Text(srv.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            StatusPill(text: state.phase.label, color: pillColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Карточка сервера

    private var serverCard: some View {
        GlassCard(glow: Theme.violet) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.neon.opacity(0.25)).frame(width: 46, height: 46)
                    Text(protocolGlyph)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.selectedServer?.title ?? "Сервер не выбран")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 6)
                pingChip
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpenServers() }
    }

    private var protocolGlyph: String {
        guard let p = state.selectedServer?.protocolName else { return "—" }
        switch p {
        case "vless": return "V"
        case "vmess": return "VM"
        case "trojan": return "TR"
        case "shadowsocks": return "SS"
        case "hysteria2": return "H2"
        case "tuic": return "TU"
        case "anytls": return "AT"
        default: return String(p.prefix(2)).uppercased()
        }
    }

    private var subtitle: String {
        guard let s = state.selectedServer else { return "добавьте ключ во вкладке Импорт" }
        return "\(s.host):\(s.port)"
    }

    private var pingChip: some View {
        let p = state.selectedServer?.ping ?? -1
        return Text(p < 0 ? "пинг —" : "\(p) мс")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(p < 0 ? Theme.text3 : (p < 150 ? Theme.ok : Theme.warn))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: Capsule())
    }

    // MARK: Трафик

    private var trafficCard: some View {
        GlassCard(glow: Theme.accent) {
            VStack(spacing: 16) {
                HStack {
                    SectionTitle(text: "Трафик")
                    Spacer()
                    Button {
                        onOpenSpeed()
                    } label: {
                        Label("Тест", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                }
                HStack(spacing: 12) {
                    speedTile(icon: "arrow.down",
                              color: Theme.accent,
                              value: Double(state.stats.downSpeed),
                              total: state.stats.downTot,
                              title: "Загрузка")
                    speedTile(icon: "arrow.up",
                              color: Theme.violet,
                              value: Double(state.stats.upSpeed),
                              total: state.stats.upTot,
                              title: "Отдача")
                }
            }
        }
    }

    private func speedTile(icon: String, color: Color, value: Double, total: Int64, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                AnimatedNumber(value: value / 1024, format: value >= 1024 * 1024 ? "%.0f" : "%.1f")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text1)
                Text(value >= 1024 * 1024 ? "МБ/с" : "КБ/с")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(byteString(total))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.text3)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * barFraction(value)))
                        .shadow(color: color.opacity(0.7), radius: 6)
                }
            }
            .frame(height: 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: value)
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.35), lineWidth: 1))
        .shadow(color: color.opacity(0.2), radius: 10, y: 3)
    }

    private func barFraction(_ v: Double) -> CGFloat {
        // логарифмическая шкала до ~50 МБ/с
        CGFloat(min(1, log10(max(v, 1)) / log10(50 * 1024 * 1024)))
    }

    // MARK: Сессия

    private func sessionCard(_ since: Date) -> some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle(text: "Сессия")
                    Text(since, style: .timer)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    SectionTitle(text: "Всего")
                    Text("↑ \(byteString(state.stats.upTot))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.violet)
                    Text("↓ \(byteString(state.stats.downTot))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: Быстрые действия

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickToggle(title: "Kill switch",
                        icon: "lock.shield",
                        isOn: Binding(get: { state.settings.killSwitch },
                                      set: { state.settings.killSwitch = $0; state.save() }))
            quickToggle(title: "Блок рекламы",
                        icon: "hand.raised.slash",
                        isOn: Binding(get: { state.settings.blockAds },
                                      set: { state.settings.blockAds = $0; state.save() }))
            quickToggle(title: "Блок LAN",
                        icon: "wifi.slash",
                        isOn: Binding(get: { state.settings.blockLan },
                                      set: { state.settings.blockLan = $0; state.save() }))
        }
    }

    private func quickToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Theme.accent : Theme.text3)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isOn.wrappedValue ? Theme.accent.opacity(0.16) : Color.white.opacity(0.06))
                )
                .overlay(Circle().stroke(isOn.wrappedValue ? Theme.accent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isOn.wrappedValue ? Theme.text2 : Theme.text3)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isOn.wrappedValue ? Theme.accent.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOn.wrappedValue.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

func byteString(_ bytes: Int64) -> String {
    let b = Double(max(0, bytes))
    if b >= 1_073_741_824 { return String(format: "%.2f ГБ", b / 1_073_741_824) }
    if b >= 1_048_576 { return String(format: "%.1f МБ", b / 1_048_576) }
    if b >= 1024 { return String(format: "%.0f КБ", b / 1024) }
    return "\(Int(b)) Б"
}
