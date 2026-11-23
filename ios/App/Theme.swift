import SwiftUI
import UIKit
import Foundation

// MARK: - Палитра

enum Theme {
    static let bg = Color(red: 0.01, green: 0.02, blue: 0.06)
    static let accent = Color(red: 0.06, green: 0.94, blue: 0.98)   // яркий неон-циан
    static let violet = Color(red: 0.72, green: 0.56, blue: 0.97)
    static let pink = Color(red: 0.95, green: 0.45, blue: 0.70)
    static let ok = Color(red: 0.18, green: 0.86, blue: 0.56)
    static let warn = Color(red: 0.96, green: 0.64, blue: 0.26)
    static let err = Color(red: 0.97, green: 0.28, blue: 0.35)

    static let text1 = Color.white
    static let text2 = Color.white.opacity(0.78)
    static let text3 = Color.white.opacity(0.48)

    static var neon: LinearGradient {
        LinearGradient(colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var neonShadow: Color { Color(red: 0.00, green: 0.95, blue: 0.98).opacity(0.75) }
}

// MARK: - Аврора-фон

/// Тёмный фон с 5-тью медленно дышащими неоновыми пятнами + мерцающие точки.
struct AuroraBackground: View {
    @State private var drift = false
    @State private var twinkle = false

    var body: some View {
        ZStack {
            Theme.bg
            blob(Theme.accent, size: 540, x: -160, y: -360, delay: 0)
            blob(Theme.violet, size: 460, x: 170, y: -120, delay: 1.8)
            blob(Theme.pink, size: 400, x: -90, y: 330, delay: 3.4)
            blob(Theme.accent.opacity(0.85), size: 260, x: 200, y: 110, delay: 5.2)
            blob(Theme.pink.opacity(0.8), size: 200, x: 60, y: 200, delay: 6.8)
            twinkles
            // светящаяся сетка-звёзды
            RadialGradient(colors: [.white.opacity(0.07), .clear], center: .topTrailing, startRadius: 0, endRadius: 560)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { twinkle = true }
        }
    }

    private var twinkles: some View {
        GeometryReader { g in
            ZStack {
                ForEach(Array(0..<22), id: \.self) { i in
                    let x = g.size.width * CGFloat((i * 37 + i * i * 13) % 23) / 23 + g.size.width / 46
                    let y = g.size.height * CGFloat((i * 29 + i * i * 7) % 19) / 19 + g.size.height / 38
                    let w = CGFloat(1 + (i % 3))
                    let phase = Double(i % 7) * 0.37
                    Circle()
                        .fill(Theme.text3.opacity(0.16))
                        .frame(width: w, height: w)
                        .opacity(twinkle ? 0.25 + 0.35 * sin(1.5 + phase) : 0.08)
                        .position(x: x, y: y)
                        .animation(.easeInOut(duration: 0.9 + Double(i % 9) * 0.3).repeatForever(autoreverses: true, delay: Double(i) * 0.07), value: twinkle)
                }
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(color.opacity(0.34))
            .frame(width: size, height: size)
            .blur(radius: 110)
            .offset(x: drift ? x + 60 : x - 45, y: drift ? y - 45 : y + 45)
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.08)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: glow.opacity(glow == .clear ? 0 : 0.45), radius: 30, y: 12)
            .shadow(color: .black.opacity(0.5), radius: 22, y: 16)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(1.8)
            .kerning(0)
            .foregroundStyle(Theme.text3)
            .lineLimit(1)
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
            if isOn {
                // пульсирующее ореольное кольцо
                Circle()
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 4)
                    .frame(width: 168, height: 168)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.75)
                    .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false), value: pulse)
                    .onAppear { pulse = true }
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: isOn
                            ? [Theme.accent.opacity(0.96), Theme.violet.opacity(0.93), Theme.pink.opacity(0.88)]
                            : [Color.white.opacity(0.17), Color.white.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 168, height: 168)
                .overlay(Circle().stroke(Color.white.opacity(isOn ? 0.35 : 0.2), lineWidth: 1.5))
                .shadow(color: isOn ? Theme.accent.opacity(0.7) : Color.white.opacity(0.1), radius: isOn ? 34 : 14, y: isOn ? 12 : 4)
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
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(isOn ? Color.white : Theme.text2)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            }
        }
        .contentShape(Circle())
        .scaleEffect(busy ? 0.97 : 1)
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
                .shadow(color: color, radius: glow ? 8 : 4)
                .opacity(glow ? 1 : 0.7)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
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
            Spacer(minLength: 10)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? onColor.opacity(0.3) : Color.white.opacity(0.12))
                    .frame(width: 60, height: 32)
                    .overlay(Capsule().stroke(configuration.isOn ? onColor.opacity(0.75) : Color.white.opacity(0.16), lineWidth: 1))
                Circle()
                    .fill(configuration.isOn ? onColor : Color.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .shadow(color: configuration.isOn ? onColor.opacity(0.9) : .clear, radius: 9)
                    .padding(3)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
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
    var fontSize: CGFloat = 14
    var height: CGFloat = 46
    let action: () -> Void

    @State private var pressed = false
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize + 2, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .shadow(color: color.opacity(0.5), radius: 12, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.5), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: pressed)
    }
}

// MARK: - Цифры

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.1f"
    @State private var shown: Double = 0

    var body: some View {
        Text(String(format: format, shown))
            .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .onAppear { shown = value }
            .onChange(of: value) { v in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { shown = v }
            }
    }
}
