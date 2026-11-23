import SwiftUI

@main
struct FirmyVPNApp: App {
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.vpn)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { url in
                    // firmyvpn://toggle — из виджета/ссылки; иначе импорт ключа
                    switch url.scheme?.lowercased() {
                    case "firmyvpn":
                        if url.host == "toggle" { state.toggle() }
                    default:
                        _ = state.importText(url.absoluteString, source: "manual")
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0

    var body: some View {
        ZStack {
            AuroraBackground()
            TabView(selection: $tab) {
                HomeView(onOpenServers: { tab = 1 }, onOpenSpeed: { tab = 3 })
                    .tabItem { Label("Подключение", systemImage: "shield.lefthalf.filled") }
                    .tag(0)
                ServersView()
                    .tabItem { Label("Серверы", systemImage: "server.rack") }
                    .tag(1)
                ImportView()
                    .tabItem { Label("Импорт", systemImage: "square.and.arrow.down") }
                    .tag(2)
                SpeedTestView()
                    .tabItem { Label("Тест скорости", systemImage: "gauge.with.dots.needle.67percent") }
                    .tag(3)
                SettingsView()
                    .tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }
                    .tag(4)
            }
            .tint(Theme.accent)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            // Глобальный масштаб интерфейса (ширина/высота, слайдеры в Настройках)
            .scaleEffect(x: CGFloat(state.settings.uiScaleX),
                         y: CGFloat(state.settings.uiScaleY),
                         anchor: .topLeading)
            // «Длина» — дополнительный вертикальный отступ содержимого
            .padding(.vertical, max(0, (state.settings.uiScaleZ - 1) * 28))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.settings.uiScaleX)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.settings.uiScaleY)
            // Ограничиваем доступность: «Крупный текст» не растягивает всё приложение
            .dynamicTypeSize(.xxxLarge)
        }
        .onChange(of: scenePhase) { p in
            guard p == .active else { return }
            Task {
                await state.vpn.prepare()
                if state.settings.autoConnect,
                   state.vpn.status == .invalid || state.vpn.status == .disconnected,
                   state.selectedServer != nil {
                    await state.connect()
                }
            }
        }
    }
}
