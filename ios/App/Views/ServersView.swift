import SwiftUI
import UIKit

struct ServersView: View {
    @EnvironmentObject var state: AppState
    @State private var pinging = false
    @State private var editMode = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if state.servers.isEmpty { empty } else { list }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 44)
            }
            .background(Color.clear)
            .navigationTitle("Серверы")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pinging = true
                        Task {
                            await state.pingAll()
                            pinging = false
                        }
                    } label: {
                        if pinging {
                            ProgressView().tint(Theme.accent)
                        } else {
                            Image(systemName: "bolt.horizontal.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .disabled(pinging || state.servers.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !state.servers.isEmpty {
                        Button(editMode ? "Готово" : "Изменить") { editMode.toggle() }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.text3)
                .padding(.top, 60)
            Text("Пока нет серверов")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text1)
                .lineLimit(1)
            Text("Импортируйте ключи во вкладке Импорт")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
    }

    private var list: some View {
        VStack(spacing: 12) {
            ForEach(Array(state.servers.enumerated()), id: \.element.id) { pair in
                row(pair.element, index: pair.offset)
            }
            .onDelete { indexSet in
                for i in indexSet {
                    let id = state.servers[i].id
                    state.servers.remove(at: i)
                    if state.settings.selectedServer == id {
                        state.settings.selectedServer = state.servers.first?.id ?? ""
                    }
                }
                state.save()
            }
        }
    }

    private func row(_ s: Server, index: Int) -> some View {
        let selected = s.id == state.selectedServer?.id
        return GlassCard(glow: selected ? Theme.accent : .clear) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selected ? Theme.neon : Color.white.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Text(glyph(s.protocolName))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? .white : Theme.accent)
                        .frame(width: 42, height: 42)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6, alignment: .firstTextBaseline) {
                        Text(s.protocolShort)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.violet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.violet.opacity(0.18), in: Capsule())
                        Text("\(s.host):\(s.port)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                pingBadge(s.ping)
                if editMode {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.err)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                state.servers.removeAll { $0.id == s.id }
                                if state.settings.selectedServer == s.id {
                                    state.settings.selectedServer = state.servers.first?.id ?? ""
                                }
                            }
                            state.save()
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !editMode else { return }
            state.switchTo(s)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .contextMenu {
            Button("Пинговать") { state.ping(index) }
            Button("Выбрать и подключить") { state.switchTo(s) }
        }
    }

    private func pingBadge(_ p: Int) -> some View {
        let color: Color = p < 0 ? Theme.text3 : (p < 120 ? Theme.ok : (p < 300 ? Theme.warn : Theme.err))
        return Text(p < 0 ? "—" : "\(p) мс")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            .frame(width: 62, alignment: .center)
    }

    private func glyph(_ p: String) -> String {
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
}
