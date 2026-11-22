import SwiftUI
import UIKit

struct ServersView: View {
    @EnvironmentObject var state: AppState
    @State private var pinging = false
    @State private var editMode = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if state.servers.isEmpty { empty } else { list }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
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
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .disabled(pinging || state.servers.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !state.servers.isEmpty {
                        Button(editMode ? "Готово" : "Изменить") { editMode.toggle() }
                            .foregroundStyle(Theme.text2)
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Theme.text3)
                .padding(.top, 80)
            Text("Пока нет серверов")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text1)
            Text("Вставьте ссылку или файл из Telegram-бота во вкладке «Импорт»")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
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
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selected ? Theme.neon : LinearGradient(colors: [Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 44)
                    Text(glyph(s))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(selected ? .white : Theme.text2)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 6) {
                        Text(s.protocolShort)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.violet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.violet.opacity(0.15), in: Capsule())
                        Text("\(s.host):\(s.port)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 8)
                pingBadge(s.ping)
                if editMode {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.err)
                        .onTapGesture {
                            state.servers.removeAll { $0.id == s.id }
                            if state.settings.selectedServer == s.id {
                                state.settings.selectedServer = state.servers.first?.id ?? ""
                            }
                            state.save()
                        }
                } else if selected && state.vpn.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.ok)
                }
            }
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
        return Text(p < 0 ? "—" : "\(p)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 54)
            .padding(.vertical, 7)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }

    private func glyph(_ s: Server) -> String {
        switch s.protocolName {
        case "vless": return "V"
        case "vmess": return "VM"
        case "trojan": return "TR"
        case "shadowsocks": return "SS"
        case "hysteria2": return "H2"
        case "tuic": return "TU"
        case "anytls": return "AT"
        default: return String(s.protocolName.prefix(2)).uppercased()
        }
    }
}
