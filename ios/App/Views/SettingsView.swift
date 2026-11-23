import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showReset = false
    @State private var groupNote: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    connectCard
                    scaleCard
                    dnsCard
                    filterCard
                    systemCard
                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.clear)
            .navigationTitle("Настройки")
            .alert("Сбросить настройки?", isPresented: $showReset) {
                Button("Сброс", role: .destructive) {
                    state.settings = AppSettings()
                    if let first = state.servers.first { state.settings.selectedServer = first.id }
                    state.save()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все переключатели вернутся в исходное состояние.")
            }
        }
        .onAppear {
            groupNote = AppGroup.isShared
                ? "Общая папка: доступна"
                : "Общая папка недоступна — настройки передаются через профиль VPN"
        }
    }

    private func toggle(_ title: String, _ icon: String, _ key: WritableKeyPath<AppSettings, Bool>, footer: String? = nil) -> some View {
        Toggle(isOn: Binding(get: { state.settings[keyPath: key] },
                             set: { state.settings[keyPath: key] = $0; state.save() })) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toggleStyle(NeonToggleStyle())
        .padding(.vertical, 4)
        .onChange(of: state.settings[keyPath: key]) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var connectCard: some View {
        settingsCard("Подключение") {
            toggle("Kill switch (ничего мимо VPN)", "lock.shield", \.killSwitch,
                   footer: "iOS: includeAllNetworks")
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Блокировать локальную сеть", "wifi.slash", \.blockLan)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Блокировать торренты", "arrow.triangle.branch", \.blockBt)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Блокировать весь UDP", "network.slash", \.udpBlock)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Жёсткая маршрутизация", "route", \.strictRoute)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Отключить IPv6", "globe.badge.chevron.backward", \.disableIPv6)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Автоподключение при запуске", "power", \.autoConnect)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Выбирать самый быстрый сервер", "bolt.fill", \.fastestServer)
        }
    }

    private var dnsCard: some View {
        settingsCard("DNS") {
            HStack(spacing: 12) {
                Image(systemName: "network")
                    .foregroundStyle(Theme.violet)
                    .frame(width: 28)
                Picker("", selection: Binding(get: { state.settings.dns },
                                              set: { state.settings.dns = $0; state.save() })) {
                    Text("Авто / Google").tag("auto")
                    Text("Cloudflare").tag("cloudflare")
                    Text("Quad9").tag("quad9")
                    Text("AdGuard").tag("adguard")
                    Text("Прямой (AliDNS)").tag("direct")
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 12) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(Theme.violet)
                    .frame(width: 28)
                TextField("Свой DNS: 1.1.1.1 или https://…", text: Binding(
                    get: { state.settings.customDNS },
                    set: { state.settings.customDNS = $0; state.save() }
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.text1)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
            .padding(.vertical, 4)
        }
    }

    private var filterCard: some View {
        settingsCard("Фильтры и правила") {
            toggle("Блокировать рекламу и трекеры", "hand.raised.slash", \.blockAds)
            Divider().overlay(Color.white.opacity(0.08))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(Theme.pink)
                        .frame(width: 28)
                    Text("Мимо VPN (домены и подсети)")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text2)
                }
                TextEditor(text: Binding(
                    get: { state.settings.bypassDomains },
                    set: { state.settings.bypassDomains = $0; state.save() }
                ))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.text1)
                .scrollContentBackground(.hidden)
                .frame(height: 84)
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("по одному в строке: example.com, 10.0.0.0/8")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.vertical, 4)
        }
    }

    private var systemCard: some View {
        settingsCard("Система") {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                Text("Уровень логов")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                Spacer()
                Picker("", selection: Binding(get: { state.settings.logLevel },
                                              set: { state.settings.logLevel = $0; state.save() })) {
                    Text("trace").tag("trace")
                    Text("debug").tag("debug")
                    Text("info").tag("info")
                    Text("warn").tag("warn")
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                .tint(Theme.accent)
            }
            .padding(.vertical, 4)
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 12) {
                Image(systemName: "network.badge.shield.half.filled")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                Text("MTU туннеля")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                Spacer()
                Stepper(value: Binding(get: { state.settings.mtu },
                                       set: { state.settings.mtu = $0; state.save() }),
                        in: 1280...9000, step: 100) {
                    Text("\(state.settings.mtu)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .frame(width: 56)
                }
                .fixedSize()
            }
            .padding(.vertical, 4)
        }
    }

    private var scaleCard: some View {
        settingsCard("Масштаб интерфейса") {
            scaleRow(icon: "arrow.left.and.right", title: "Ширина", keyPath: \.uiScaleX)
            Divider().overlay(Color.white.opacity(0.08))
            scaleRow(icon: "arrow.up.and.down", title: "Высота", keyPath: \.uiScaleY)
        }
    }

    private func scaleRow(icon: String, title: String, keyPath: WritableKeyPath<AppSettings, Double>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(String(format: "%.2f", state.settings[keyPath: keyPath]))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
            Button {
                state.settings[keyPath: keyPath] = min(max(state.settings[keyPath: keyPath] - 0.05, 0.6), 1.4)
                state.save()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Button {
                state.settings[keyPath: keyPath] = min(max(state.settings[keyPath: keyPath] + 0.05, 0.6), 1.4)
                state.save()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var aboutCard: some View {
        settingsCard("О приложении") {
            infoRow(icon: "app.badge.checkmark", title: "Версия",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            Divider().overlay(Color.white.opacity(0.08))
            infoRow(icon: "folder.circle", title: "Хранилище",
                    value: AppGroup.isShared ? "App Group" : "профиль VPN")
            if let note = groupNote, !AppGroup.isShared {
                Divider().overlay(Color.white.opacity(0.08))
                Text(note)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.warn)
            }
            Divider().overlay(Color.white.opacity(0.08))
            Button {
                state.clearLogs()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash").foregroundStyle(Theme.err).frame(width: 28)
                    Text("Очистить журнал")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.err)
                    Spacer()
                }
            }
            Divider().overlay(Color.white.opacity(0.08))
            Button {
                showReset = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise").foregroundStyle(Theme.warn).frame(width: 28)
                    Text("Сбросить настройки")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.warn)
                    Spacer()
                }
            }
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 28)
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text2)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text3)
        }
        .padding(.vertical, 4)
    }

    private func settingsCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: title)
            GlassCard { content() }
        }
    }
}
