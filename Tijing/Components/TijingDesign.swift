import SwiftUI

// MARK: - Visual language
// A warm, paper-like system that keeps native iOS interaction while avoiding
// the "every screen is a Form" feeling. The palette is deliberately soft so
// content, avatars and progress stay in front.
enum TijingDesign {
    static let pageHorizontalPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 28
    static let cardRadius: CGFloat = 26
    static let compactRadius: CGFloat = 18

    static let ink = Color(uiColor: .label)
    static let indigo = Color(red: 0.35, green: 0.39, blue: 0.86)
    static let violet = Color(red: 0.58, green: 0.48, blue: 0.86)
    static let cyan = Color(red: 0.30, green: 0.69, blue: 0.82)
    static let mint = Color(red: 0.35, green: 0.69, blue: 0.55)
    static let amber = Color(red: 0.93, green: 0.65, blue: 0.25)
    static let coral = Color(red: 0.93, green: 0.43, blue: 0.45)

    static let peach = Color(red: 0.96, green: 0.78, blue: 0.67)
    static let butter = Color(red: 0.96, green: 0.88, blue: 0.59)
    static let sage = Color(red: 0.75, green: 0.84, blue: 0.68)
    static let sky = Color(red: 0.72, green: 0.84, blue: 0.94)
    static let lilac = Color(red: 0.82, green: 0.77, blue: 0.93)
    static let rose = Color(red: 0.94, green: 0.76, blue: 0.79)

    static let primaryGradient = LinearGradient(
        colors: [indigo.opacity(0.96), violet.opacity(0.90)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let battleGradient = LinearGradient(
        colors: [indigo.opacity(0.90), violet.opacity(0.82), cyan.opacity(0.70)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct TijingDotGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.08

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 1.7, height: 1.7))
            var y: CGFloat = 8
            while y < size.height {
                var x: CGFloat = 8
                while x < size.width {
                    context.drawLayer { layer in
                        layer.translateBy(x: x, y: y)
                        layer.fill(dot, with: .color((colorScheme == .dark ? Color.white : Color.black).opacity(opacity)))
                    }
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct TijingPageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: colorScheme == .dark ? .systemBackground : .systemGroupedBackground)
            LinearGradient(
                colors: [
                    TijingDesign.peach.opacity(colorScheme == .dark ? 0.06 : 0.12),
                    TijingDesign.sky.opacity(colorScheme == .dark ? 0.05 : 0.09),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            TijingDotGrid(opacity: colorScheme == .dark ? 0.045 : 0.055)
        }
        .ignoresSafeArea()
    }
}

struct TijingSectionHeading: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TijingHeroCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let gradient: LinearGradient
    private let content: Content

    init(
        gradient: LinearGradient = TijingDesign.primaryGradient,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            gradient
            TijingDotGrid(opacity: 0.07)
                .blendMode(.softLight)

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 140, height: 140)
                .offset(x: 46, y: -58)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.07), radius: colorScheme == .dark ? 12 : 20, y: colorScheme == .dark ? 5 : 10)
        .accessibilityElement(children: .contain)
    }
}

struct TijingPastelCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    var minHeight: CGFloat? = nil
    private let content: Content

    init(tint: Color, minHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.16 : 0.42))
            TijingDotGrid(opacity: 0.045)
                .clipShape(RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
            Circle()
                .fill((colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.28)))
                .frame(width: 88, height: 88)
                .offset(x: 24, y: -28)
            content
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        }
    }
}

struct TijingMetricTile: View {
    let value: String
    let title: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.38), value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: TijingDesign.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.compactRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045))
        }
    }
}

struct TijingCompactMetric: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.38), value: value)
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TijingActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor
    var emphasis: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(emphasis ? .white : tint)
                    .frame(width: 42, height: 42)
                    .background(emphasis ? Color.white.opacity(0.16) : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(emphasis ? Color.white.opacity(0.75) : Color.secondary)
            }

            Spacer(minLength: 2)

            Text(title)
                .font(.headline)
                .foregroundStyle(emphasis ? .white : .primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(emphasis ? Color.white.opacity(0.78) : Color.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background {
            if emphasis {
                LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .strokeBorder(emphasis ? Color.white.opacity(0.14) : Color.primary.opacity(0.045))
        }
    }
}

struct TijingSettingsGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045))
        }
    }
}

struct TijingSettingsRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var tint: Color = .accentColor
    var trailing: String? = nil

    init(_ title: String, subtitle: String? = nil, systemImage: String, tint: Color = .accentColor, trailing: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct TijingTag: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
    }
}

struct TijingFieldSurface<Content: View>: View {
    let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045))
        }
    }
}

struct TijingProgressRing: View {
    let progress: Double
    let value: String
    let caption: String

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: 9)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.38), value: value)
                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
        .frame(width: 104, height: 104)
        .animation(.snappy(duration: 0.45), value: progress)
    }
}

struct TijingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(TijingDesign.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .opacity(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct TijingPressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.978 : 1)
            .opacity(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.80), value: configuration.isPressed)
    }
}

extension View {
    func tijingCard() -> some View {
        self
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.045))
            }
    }

    func tijingTactileLink() -> some View {
        self.simultaneousGesture(TapGesture().onEnded { Haptics.light() })
    }
}

// MARK: - Delight details
// Small sticker-like symbols inspired by the tactile, collectible feeling of
// modern learning apps. They stay decorative; all primary interaction remains
// native SwiftUI controls.
struct TijingStickerIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    var tint: Color = TijingDesign.indigo
    var background: Color = TijingDesign.butter
    var size: CGFloat = 48
    var rotation: Double = -5
    var sparkle: Bool = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(background.opacity(colorScheme == .dark ? 0.42 : 0.92))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.05), radius: 8, y: 4)

            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: size, height: size)

            if sparkle {
                Image(systemName: "sparkle")
                    .font(.system(size: max(9, size * 0.19), weight: .bold))
                    .foregroundStyle(tint.opacity(0.70))
                    .offset(x: size * 0.08, y: -size * 0.07)
            }
        }
        .frame(width: size + 4, height: size + 4)
        .accessibilityHidden(true)
    }
}

struct TijingPaperCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var tint: Color = TijingDesign.sky
    var rotation: Double = 0
    private let content: Content

    init(tint: Color = TijingDesign.sky, rotation: Double = 0, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.rotation = rotation
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
            LinearGradient(
                colors: [tint.opacity(colorScheme == .dark ? 0.10 : 0.20), tint.opacity(colorScheme == .dark ? 0.025 : 0.04), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(tint.opacity(colorScheme == .dark ? 0.10 : 0.22))
                .frame(width: 58, height: 58)
                .offset(x: 22, y: -26)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.045), radius: colorScheme == .dark ? 9 : 14, y: colorScheme == .dark ? 4 : 8)
        .rotationEffect(.degrees(rotation))
    }
}

struct TijingMicroBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = TijingDesign.indigo

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

struct TijingMiniStatRow: View {
    let systemImage: String
    let title: String
    let value: String
    var tint: Color = TijingDesign.indigo

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.34), value: value)
        }
    }
}

struct TijingFloatingSparkles: View {
    var tint: Color = TijingDesign.amber

    var body: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.caption.bold())
                .offset(x: -9, y: -8)
            Image(systemName: "sparkles")
                .font(.caption2.bold())
                .offset(x: 9, y: 8)
        }
        .foregroundStyle(tint.opacity(0.80))
        .accessibilityHidden(true)
    }
}


// MARK: - Motion and tactile polish
private struct TijingRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let order: Int
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || reduceMotion ? 0 : 10)
            .scaleEffect(revealed || reduceMotion ? 1 : 0.985)
            .onAppear {
                guard !revealed else { return }
                if reduceMotion {
                    revealed = true
                } else {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.84).delay(Double(order) * 0.045)) {
                        revealed = true
                    }
                }
            }
    }
}

extension View {
    func tijingReveal(order: Int = 0) -> some View {
        modifier(TijingRevealModifier(order: order))
    }
}

struct TijingInteractiveAvatar: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 46
    @GestureState private var pressed = false

    var body: some View {
        RemoteAvatar(urlString: urlString, name: name, size: size)
            .scaleEffect(pressed ? 0.92 : 1)
            .shadow(color: Color.black.opacity(pressed ? 0.03 : 0.07), radius: pressed ? 2 : 7, y: pressed ? 1 : 3)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
            )
    }
}

struct TijingMatchmakingPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color = .white

    var body: some View {
        TimelineView(AnimationTimelineSchedule(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let phase = (t * 0.42 + Double(index) * 0.27).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(tint.opacity(0.28 * (1 - phase)), lineWidth: 1.5)
                        .frame(width: 28 + CGFloat(phase) * 58, height: 28 + CGFloat(phase) * 58)
                }

                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)

                if !reduceMotion {
                    orbitDot(angle: t * 2.0, radius: 33, size: 6)
                    orbitDot(angle: -t * 1.45 + 2.1, radius: 25, size: 5)
                }
            }
            .frame(width: 96, height: 96)
        }
        .accessibilityHidden(true)
    }

    private func orbitDot(angle: Double, radius: CGFloat, size: CGFloat) -> some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            .shadow(color: tint.opacity(0.35), radius: 4)
    }
}
