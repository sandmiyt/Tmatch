import SwiftUI

// MARK: - Brand language

enum TijingDesign {
    static let pageHorizontalPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 26
    static let cardRadius: CGFloat = 24
    static let compactRadius: CGFloat = 18

    static let indigo = Color(red: 0.29, green: 0.31, blue: 0.96)
    static let violet = Color(red: 0.57, green: 0.31, blue: 0.98)
    static let cyan = Color(red: 0.14, green: 0.72, blue: 0.94)
    static let mint = Color(red: 0.17, green: 0.76, blue: 0.58)
    static let amber = Color(red: 0.98, green: 0.65, blue: 0.18)
    static let coral = Color(red: 0.98, green: 0.39, blue: 0.42)

    static let primaryGradient = LinearGradient(
        colors: [Color.accentColor, indigo, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let battleGradient = LinearGradient(
        colors: [indigo, Color.accentColor, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct TijingPageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10),
                    TijingDesign.violet.opacity(colorScheme == .dark ? 0.09 : 0.045),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
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
        VStack(alignment: .leading, spacing: 3) {
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

            Circle()
                .fill(.white.opacity(0.13))
                .frame(width: 150, height: 150)
                .offset(x: 48, y: -58)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 86, height: 86)
                .offset(x: -20, y: 120)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: TijingDesign.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.compactRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        }
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
                    .background(
                        emphasis ? Color.white.opacity(0.16) : tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
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
                    .fill(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .strokeBorder(emphasis ? Color.white.opacity(0.14) : Color.primary.opacity(0.055))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055))
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

struct TijingProgressRing: View {
    let progress: Double
    let value: String
    let caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 9)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
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
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct TijingPressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

extension View {
    func tijingCard() -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055))
            }
    }

    func tijingTactileLink() -> some View {
        self.simultaneousGesture(TapGesture().onEnded { Haptics.light() })
    }
}
