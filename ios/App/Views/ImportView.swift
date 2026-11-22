import SwiftUI
import UniformTypeIdentifiers

/// Импорт ровно в два шага: «Подписка» или «Файл» — как в PC-версии.
struct ImportView: View {
    @EnvironmentObject var state: AppState

    @State private var tab = 0
    @State private var subURL = ""
    @State private var subName = ""
    @State private var busy = false
    @State private var banner: String?
    @State private var showFile = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Picker("", selection: $tab) {
                        Text("Подписка").tag(0)
                        Text("Файл").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    if tab == 0 { subscriptionCard } else { fileCard }

                    if let b = banner ?? state.importBanner {
                        bannerView(b)
                    }

                    infoCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.clear)
            .navigationTitle("Импорт")
            .fileImporter(isPresented: $showFile,
                          allowedContentTypes: [.plainText, .json, .text, .data]
                            + [UTType(filenameExtension: "yaml"), UTType(filenameExtension: "yml")].compactMap { $0 },
                          allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                Task {
                    do {
                        let access = url.startAccessingSecurityScopedResource()
                        let text = try String(contentsOf: url, encoding: .utf8)
                        if access { url.stopAccessingSecurityScopedResource() }
                        _ = state.importText(text, source: "file",
                                              subURL: "", subName: url.lastPathComponent)
                        banner = state.importBanner
                    } catch {
                        banner = "Не удалось прочитать файл: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: Подписка

    private var subscriptionCard: some View {
        GlassCard(glow: Theme.violet) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(Theme.violet)
                        .frame(width: 36, height: 36)
                        .background(Theme.violet.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ссылка подписки")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("Telegram-боты: https://… или base64")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.text3)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                inputField(icon: "globe", placeholder: "https://t.me/… или https://sub.example/…", text: $subURL)
                inputField(icon: "tag", placeholder: "Название (необязательно)", text: $subName)
                NeonButton(title: busy ? "Загрузка…" : "Добавить подписку",
                           icon: busy ? nil : "arrow.down.circle.fill",
                           color: Theme.violet) {
                    Task {
                        busy = true
                        banner = nil
                        let err = await state.fetchSubscription(subURL, name: subName.isEmpty ? "Подписка" : subName)
                        busy = false
                        banner = err ?? state.importBanner
                        if err == nil { subURL = "" }
                    }
                }
                .disabled(busy || subURL.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(subURL.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
            }
        }
    }

    // MARK: Файл

    private var fileCard: some View {
        GlassCard(glow: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.plaintext")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36)
                        .background(Theme.accent.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Файл с ключами")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text1)
                        Text("txt · json · yaml (Clash) · подписка")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.text3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Сохраните файл из Telegram («Поделиться → Сохранить в Файлы») и выберите его здесь.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NeonButton(title: "Выбрать файл", icon: "folder.fill", color: Theme.accent) {
                    showFile = true
                }
            }
        }
    }

    // MARK: Прочее

    private func inputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.text3)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.text1)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func bannerView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: text.contains("Ошибка") || text.contains("не") || text.contains("Ничего") ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text2)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var infoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Поддерживаемые форматы")
                FlowTags(tags: ["vless://", "vmess://", "trojan://", "ss://",
                                "hysteria2://", "tuic://", "anytls://",
                                "base64-подписка", "sing-box JSON", "Clash YAML"])
            }
        }
    }
}

/// Простая обёртка строк тегов.
struct FlowTags: View {
    let tags: [String]
    private let columns = [GridItem(.adaptive(minimum: 70), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { t in
                Text(t)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
}
