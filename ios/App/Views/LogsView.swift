import SwiftUI

/// Журнал ядра: строки из общей папки (или через сообщение расширению).
struct LogsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    if state.logs.isEmpty {
                        HStack {
                            Image(systemName: "scroll")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(Theme.text3)
                                .padding(.top, 70)
                            Text("Журнал пуст — подключитесь, чтобы увидеть записи ядра.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Theme.text3)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 14)
                        }
                    }
                    ForEach(Array(state.logs.enumerated()), id: \.offset) { _, line in
                        logRow(line)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .background(Color.clear)
            .navigationTitle("Журнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { state.clearLogs() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.err)
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

    private func logRow(_ line: (time: String, source: String, text: String)) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(line.time.replacingOccurrences(of: "T", with: " ").prefix(19))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 62, alignment: .trailing)
            Text("[\(line.source)]")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color(line.source))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 40, alignment: .leading)
            Text(line.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.text2)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
