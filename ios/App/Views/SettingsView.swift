import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showReset = false
    @State private var groupNote: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    connectCard
                    scaleCard
                    dnsCard
                    filterCard
                    systemCard
                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 44)
            }
            .background(Color.clear)
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(state.settings.blockAds ? "Обновить" : "Режимы") { state.settings.blockAds = !state.settings.blockAds; state.save() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
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
                : "Настройки передаются через профиль VPN"
        }
    }

    // MARK: Подключение

    private var connectCard: some View {
        settingsCard("Подключение") {
            toggle("Kill switch — ничего мимо VPN", "lock.shield", \.killSwitch)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Блокировать локальную сеть (LAN)", "wifi.slash", \.blockLan)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Блокировать весь UDP", "network.slash", \.udpBlock)
            Divider().overlay(Color.white.opacity(0.08))
            toggle("Автоподключение при запуске", "power", \.autoConnect)
        }
    }

    private func toggle(_ title: String, _ icon: String, _ key: WritableKeyPath<AppSettings, Bool>) -> some View {
        Toggle(isOn: Binding(get: { state.settings[keyPath: key] },
                             set: { state.settings[keyPath: key] = $0; state.save() })) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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

    // MARK: Масштаб

    private var scaleCard: some View {
        settingsCard("Масштаб интерфейса") {
            VStack(spacing: 8) {
                scaleRow(title: "Ширина", value: state.settings.uiScaleX) { v in
                    state.settings.uiScaleX = v
                }
                Divider().overlay(Color.white.opacity(0.08))
                scaleRow(title: "Высота", value: state.settings.uiScaleY) { v in
                    state.settings.uiScaleY = v
                }
                Divider().overlay(Color.white.opacity(0.08))
                scaleRow(title: "Длина", value: state.settings.uiScaleZ) { v in
                    state.settings.uiScaleZ = v
                }
            }
        }
    }

    private let scaleValues: [Double] = (60...140).map { Double($0) / 100.0 }

    private func scaleRow(title: String, value: Double, setter: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 6, alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
            Text(String(format: "%.2f", value))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()
            Button {
                setter(nextScale(value))
                state.save()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Theme.accent.opacity(0.7), lineWidth: 1))
        }
        .padding(.vertical, 5)
    }

    /// Цикл по шагам 0.01 (60…140): позволяет выставить ЛЮБОЕ значение за ~10 нажатий.
    private func nextScale(_ current: Double) -> Double {
        let idx = scaleValues.indices.max { scaleValues[$0] <= current + 0.001 } ?? -1
        guard idx >= 0 else { return scaleValues[0] }
        return idx + 1 < scaleValues.count ? scaleValues[idx + 1] : scaleValues[0]
    }

    // MARK: DNS

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
                .frame(maxWidth: .infinity)
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
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.text1)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Фильтры

    private var filterCard: some View {
        settingsCard("Фильтры и правила") {
            toggle("Блокировать рекламу и трекеры", "hand.raised.slash", \.blockAds)
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(Theme.pink)
                    .frame(width: 28)
                Text("Мимо VPN (домены и подсети)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TextEditor(text: Binding(
                get: { state.settings.bypassDomains },
                set: { state.settings.bypassDomains = $0; state.save() }
            ))
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Theme.text1)
            .scrollContentBackground(.hidden)
            .frame(height: 84)
            .padding(10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .lineLimit(4)
            Text("По одному домену или подсети в строке")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
        }
    }

    // MARK: Система

    private var systemCard: some View {
        settingsCard("Система") {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                Text("Уровень логов")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Picker("", selection: Binding(get: { state.settings.logLevel },
                                              set: { state.settings.logLevel = $0; state.save() })) {
                    Text("trace").tag("trace")
                    Text("debug").tag("debug")
                    Text("info").tag("info")
                    Text("warn").tag("warn")
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .tint(Theme.accent)
            }
            .padding(.vertical, 4)
            Divider().overlay(Color.white.opacity(0.08))
            HStack(spacing: 12) {
                Image(systemName: "network.badge.shield.half.filled")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                Text("MTU туннеля")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Stepper(value: Binding(get: { state.settings.mtu },
                                       set: { state.settings.mtu = $0; state.save() }),
                        in: 1280...9000, step: 100) {
                    Text("\(state.settings.mtu)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .frame(width: 52)
                }
                .fixedSize()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: О приложении

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
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            Divider().overlay(Color.white.opacity(0.08))
            Button {
                state.clearLogs()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash").foregroundStyle(Theme.err).frame(width: 28)
                    Text("Очистить журнал")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
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
                        .font(.system(size: 14, weight: .medium, design: .rounded))
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
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
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
