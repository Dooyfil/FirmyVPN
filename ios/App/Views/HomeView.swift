import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var vpn: VPNController
    var onOpenServers: () -> Void = {}
    var onOpenSpeed: () -> Void = {}

    @State private var showLog = false

    private var busy: Bool { state.phase == .connecting || state.phase == .switching }
    private var on: Bool { state.phase == .connected }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    statusCard
                    PowerButton(isOn: on, busy: busy) { state.toggle() }
                        .padding(.top, 6)
                    serverCard
                    trafficCard
                    quickActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 44)
            }
            .background(Color.clear)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showLog = true } label: {
                        Image(systemName: "scroll")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showLog) { LogsView() }
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

    // MARK: Карточка статуса

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8, alignment: .center) {
                Text(state.phase.label)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(on ? Theme.ok : Theme.text1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: state.phase)
                StatusPill(text: state.phase.label, color: pillColor)
                    .frame(height: 32)
            }

            if let err = state.lastError, state.phase == .error {
                Text(err)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.err)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            if let srv = state.selectedServer {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.16)).frame(width: 38, height: 38)
                        Text(protocolGlyph(srv.protocolName))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(srv.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(subtitle)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    pingChip
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func protocolGlyph(_ p: String) -> String {
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
        guard let s = state.selectedServer else { return "подключите сервер в Импорте" }
        return "\(s.host):\(s.port)"
    }
    private var pingChip: some View {
        let p = state.selectedServer?.ping ?? -1
        return Text(p < 0 ? "пинг —" : "\(p) мс")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(p < 0 ? Theme.text3 : (p < 120 ? Theme.ok : Theme.warn))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    // MARK: Карточка сервера

    private var serverCard: some View {
        GlassCard(glow: on ? Theme.accent : .clear) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.neon.opacity(0.24)).frame(width: 42, height: 42)
                    if let srv = state.selectedServer {
                        Text(protocolGlyph(srv.protocolName))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(state.selectedServer?.title ?? "Подключите сервер в Импорте")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpenServers() }
    }

    // MARK: Трафик и сессия

    private var trafficCard: some View {
        GlassCard(glow: on ? Theme.accent : .clear) {
            VStack(spacing: 12) {
                SectionTitle(text: on ? "Текущий трафик" : "Трафик")
                HStack(spacing: 10) {
                    speedTile(icon: "arrow.down", color: Theme.accent, value: Double(state.stats.downSpeed),
                              title: "Загрузка", on: on)
                    speedTile(icon: "arrow.up", color: Theme.violet, value: Double(state.stats.upSpeed),
                              title: "Отдача", on: on)
                }
                HStack(spacing: 10) {
                    infoTile(icon: "arrow.up.circle", title: "Всего ↑", value: byteString(state.stats.upTot))
                    infoTile(icon: "arrow.down.circle", title: "Всего ↓", value: byteString(state.stats.downTot))
                    if let since = vpn.connectedSince {
                        infoTile(icon: "stopwatch", title: "Сессия", value: elapsed(since), isSession: true)
                    }
                }
                HStack(spacing: 10) {
                    quickToggle(title: "Kill switch", icon: "lock.shield",
                                isOn: Binding(get: { state.settings.killSwitch }, set: { v in state.settings.killSwitch = v; state.save() }))
                    quickToggle(title: "Блок рекламы", icon: "hand.raised.slash",
                                isOn: Binding(get: { state.settings.blockAds }, set: { v in state.settings.blockAds = v; state.save() }))
                    quickToggle(title: "Блок LAN", icon: "wifi.slash",
                                isOn: Binding(get: { state.settings.blockLan }, set: { v in state.settings.blockLan = v; state.save() }))
                }
            }
        }
    }

    private func speedTile(icon: String, color: Color, value: Double, title: String, on: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                AnimatedNumber(value: value / 1024, format: value >= 1024 * 1024 ? "%.0f" : "%.1f")
                    .font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.text1)
                Text(value >= 1024 * 1024 ? "МБ/с" : "КБ/с")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(byteString(Int64(value)))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(on ? 0.6 : 0.12), lineWidth: 1))
    }

    private func infoTile(icon: String, title: String, value: String, isSession: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.text1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Быстрые действия

    private var quickActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                quickToggle(title: "Kill switch",
                            icon: "lock.shield",
                            isOn: Binding(get: { state.settings.killSwitch },
                                          set: { state.settings.killSwitch = $0; state.save() }))
                quickToggle(title: "Блок рекламы",
                            icon: "hand.raised.slash",
                            isOn: Binding(get: { state.settings.blockAds },
                                          set: { state.settings.blockAds = $0; state.save() }))
            }
            HStack(spacing: 8) {
                quickToggle(title: "Блок LAN",
                            icon: "wifi.slash",
                            isOn: Binding(get: { state.settings.blockLan },
                                          set: { state.settings.blockLan = $0; state.save() }))
                quickToggle(title: "Блок UDP",
                            icon: "network.slash",
                            isOn: Binding(get: { state.settings.udpBlock },
                                          set: { state.settings.udpBlock = $0; state.save() }))
            }
        }
    }

    private func quickToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Theme.accent : Theme.text3)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(isOn.wrappedValue ? Theme.accent.opacity(0.14) : Color.white.opacity(0.06))
                )
                .overlay(Circle().stroke(isOn.wrappedValue ? Theme.accent.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1))
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isOn.wrappedValue ? Theme.text2 : Theme.text3)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isOn.wrappedValue ? Theme.accent.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOn.wrappedValue.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func elapsed(_ since: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(since)))
        let m = s / 60, h = m / 60
        if h > 0 { return "\(h) ч \(m % 60) мин" }
        if m > 0 { return "\(m) мин" }
        return "\(s) сек"
    }
}

func byteString(_ bytes: Int64) -> String {
    let b = Double(max(0, bytes))
    if b >= 1_073_741_824 { return String(format: "%.2f ГБ", b / 1_073_741_824) }
    if b >= 1_048_576 { return String(format: "%.1f МБ", b / 1_048_576) }
    if b >= 1024 { return String(format: "%.0f КБ", b / 1024) }
    return "\(Int(b)) Б"
}
