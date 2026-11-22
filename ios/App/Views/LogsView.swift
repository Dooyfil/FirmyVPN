import SwiftUI

/// Журнал ядра: строки из общей папки (или через сообщение расширению).
struct LogsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if state.logs.isEmpty {
                        Text("Журнал пуст — подключитесь, чтобы увидеть записи ядра.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Theme.text3)
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    ForEach(Array(state.logs.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(line.time.replacingOccurrences(of: "T", with: " ").prefix(19))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.text3)
                            Text("[\(line.source)]")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(color(line.source))
                            Text(line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.text2)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(Color.clear)
            .navigationTitle("Журнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(Theme.text2)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        state.clearLogs()
                    } label: {
                        Image(systemName: "trash").foregroundStyle(Theme.err)
                    }
                }
            }
        }
        .onAppear {
            state.refreshLogs()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                Task { @MainActor in state.refreshLogs() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func color(_ source: String) -> Color {
        switch source {
        case "error", "crash": return Theme.err
        case "warn": return Theme.warn
        case "app", "import": return Theme.violet
        default: return Theme.accent
        }
    }
}
