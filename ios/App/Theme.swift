import SwiftUI
import UIKit

// MARK: - Палитра

enum Theme {
    static let bg = Color(red: 0.02, green: 0.03, blue: 0.07)
    static let accent = Color(red: 0.13, green: 0.83, blue: 0.93)   // неон-циан
    static let violet = Color(red: 0.65, green: 0.55, blue: 0.98)   // фиолет
    static let pink = Color(red: 0.96, green: 0.45, blue: 0.71)     // розовый
    static let ok = Color(red: 0.20, green: 0.85, blue: 0.60)       // зелёный
    static let warn = Color(red: 1.00, green: 0.72, blue: 0.28)
    static let err = Color(red: 1.00, green: 0.35, blue: 0.42)

    static let text1 = Color.white
    static let text2 = Color.white.opacity(0.72)
    static let text3 = Color.white.opacity(0.45)

    static var neon: LinearGradient {
        LinearGradient(colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Аврора-фон

/// Тёмный фон с тремя медленно дышащими неоновыми пятнами.
struct AuroraBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.bg
            blob(Theme.accent, size: 480, x: -150, y: -330, delay: 0)
            blob(Theme.violet, size: 440, x: 160, y: -80, delay: 1.8)
            blob(Theme.pink, size: 400, x: -90, y: 330, delay: 3.4)
            blob(Theme.accent.opacity(0.8), size: 300, x: 200, y: 90, delay: 5.2)
            // лёгкая сетка-звёзды
            RadialGradient(colors: [.white.opacity(0.05), .clear], center: .topTrailing, startRadius: 0, endRadius: 500)
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(color.opacity(0.32))
            .frame(width: size, height: size)
            .blur(radius: 100)
            .offset(x: drift ? x + 50 : x - 40, y: drift ? y - 40 : y + 40)
            .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true).delay(delay), value: drift)
            .onAppear { drift = true }
    }
}

// MARK: - Стекло

struct GlassCard<Content: View>: View {
    var glow: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.08)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: glow.opacity(glow == .clear ? 0 : 0.5), radius: 28, y: 12)
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(Theme.text3)
            .padding(.leading, 6)
    }
}

// MARK: - Кнопка питания

struct PowerButton: View {
    let isOn: Bool
    let busy: Bool
    let action: () -> Void

    @State private var pulse = false
    @State private var press = false
    @State private var spin = false

    var body: some View {
        ZStack {
            // внешнее свечение вокруг подключённой кнопки
            if isOn {
                Circle()
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 5)
                    .frame(width: 168, height: 168)
                    .scaleEffect(pulse ? 1.75 : 1)
                    .opacity(pulse ? 0 : 0.75)
                    .animation(.easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(0.7), value: pulse)
            }

            // расходящиеся волны при подключении
            if isOn {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Theme.accent.opacity(0.55), lineWidth: 2)
                        .frame(width: 168, height: 168)
                        .scaleEffect(pulse ? 1.55 : 1.0)
                        .opacity(pulse ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 1.2),
                            value: pulse
                        )
                }
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: isOn
                            ? [Theme.accent.opacity(0.95), Theme.violet.opacity(0.9)]
                            : [Color.white.opacity(0.16), Color.white.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 168, height: 168)
                .overlay(Circle().stroke(Color.white.opacity(isOn ? 0.35 : 0.18), lineWidth: 1.5))
                .shadow(color: (isOn ? Theme.accent : .white).opacity(isOn ? 0.55 : 0.12), radius: isOn ? 34 : 14)
                .scaleEffect(press ? 0.93 : 1)

            if busy {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                    .onAppear { spin = true }
            } else {
                Image(systemName: "power")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Theme.text2)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            }
        }
        .contentShape(Circle())
        .scaleEffect(busy ? 0.97 : 1)
        .onAppear { if isOn { pulse = true } }
        .onChange(of: isOn) { on in
            pulse = on
            if on {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !press { press = true } }
                .onEnded { _ in
                    press = false
                    action()
                }
        )
        .accessibilityLabel(isOn ? "Отключить" : "Подключить")
    }
}

// MARK: - Статус-пилюля

struct StatusPill: View {
    let text: String
    let color: Color
    @State private var glow = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color, radius: glow ? 7 : 3)
                .opacity(glow ? 1 : 0.65)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow.toggle() }
        }
    }
}

// MARK: - Неон-тумблер

struct NeonToggleStyle: ToggleStyle {
    var onColor: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundStyle(Theme.text2)
            Spacer(minLength: 12)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? onColor.opacity(0.28) : Color.white.opacity(0.10))
                    .frame(width: 52, height: 30)
                    .overlay(Capsule().stroke(configuration.isOn ? onColor.opacity(0.7) : Color.white.opacity(0.14), lineWidth: 1))
                Circle()
                    .fill(configuration.isOn ? onColor : Color.white.opacity(0.65))
                    .frame(width: 24, height: 24)
                    .shadow(color: configuration.isOn ? onColor.opacity(0.8) : .clear, radius: 8)
                    .padding(3)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isOn)
            .onTapGesture { withAnimation { configuration.isOn.toggle() } }
        }
    }
}

// MARK: - Кнопки

struct NeonButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.accent
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background {
                if filled {
                    Capsule().fill(LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: color.opacity(0.45), radius: 14, y: 6)
                } else {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().stroke(color.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Цифры

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.1f"
    @State private var shown: Double = 0

    var body: some View {
        Text(String(format: format, shown))
            .monospacedDigit()
            .onAppear { shown = value }
            .onChange(of: value) { v in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { shown = v }
            }
    }
}
