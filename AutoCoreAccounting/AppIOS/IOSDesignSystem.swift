import SwiftUI

#if os(iOS)

// MARK: - Adaptive Palette (Flowly)

enum IOSPalette {
    /// Flowly Blue — основной синий для хедеров и акцентов
    static let flowlyBlue = Color(red: 0.04, green: 0.52, blue: 1)
    static let flowlyBlueDark = Color(red: 0.08, green: 0.45, blue: 0.95)

    static let backgroundBase = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    })
    static let backgroundLayer = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
            : UIColor.white
    })
    static let backgroundElevated = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
            : UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
    })
    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .white : UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    })
    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.65, blue: 0.68, alpha: 1)
            : UIColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1)
    })
    static let border = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor(red: 0.78, green: 0.78, blue: 0.82, alpha: 0.6)
    })

    static let accentA = Color(red: 0.04, green: 0.52, blue: 1)
    static let accentB = Color(red: 0.08, green: 0.45, blue: 0.95)
    static let positive = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let negative = Color(red: 0.95, green: 0.29, blue: 0.38)
    static let warning = Color(red: 0.98, green: 0.71, blue: 0.22)

    static let houseOrange = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.28, blue: 0.2, alpha: 1)
            : UIColor(red: 1, green: 0.92, blue: 0.8, alpha: 1)
    })
    static let travelBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.25, blue: 0.35, alpha: 1)
            : UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)
    })
    static let shoppingPink = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.22, blue: 0.28, alpha: 1)
            : UIColor(red: 1, green: 0.92, blue: 0.95, alpha: 1)
    })
    static let healthGreen = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.32, blue: 0.25, alpha: 1)
            : UIColor(red: 0.85, green: 0.98, blue: 0.9, alpha: 1)
    })

    static let progressTrack = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.2)
            : UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1)
    })

    static let screenGradient = LinearGradient(
        colors: [
            IOSPalette.backgroundBase,
            IOSPalette.backgroundLayer,
            IOSPalette.backgroundBase
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [IOSPalette.flowlyBlue, IOSPalette.flowlyBlueDark],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Fintech login screen gradient: bright blue → darker blue
    static let loginGradient = LinearGradient(
        colors: [
            Color(red: 0.184, green: 0.502, blue: 0.929),
            Color(red: 0.11, green: 0.431, blue: 0.835),
            Color(red: 0.059, green: 0.243, blue: 0.541)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [IOSPalette.backgroundLayer, IOSPalette.backgroundElevated],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum IOSMotion {
    static let quick = Animation.easeInOut(duration: 0.18)
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let emphasis = Animation.spring(response: 0.44, dampingFraction: 0.76)
    static let appear = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let chartBars = Animation.spring(response: 0.6, dampingFraction: 0.7)
}

/// iOS‑специфичная обёртка над дизайн-токенами.
enum IOSDesign {
    enum Radius {
        static let chip: CGFloat = 999
        static let card: CGFloat = 20
        static let button: CGFloat = 16
        static let screenCard: CGFloat = 24
    }

    enum Typography {
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 26, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 15, weight: .regular)
        static let section = Font.system(size: 12, weight: .semibold)
        static let badge = Font.system(size: 11, weight: .medium)
        static let number = Font.system(size: 28, weight: .bold, design: .rounded)
        static let cardNumber = Font.system(size: 22, weight: .bold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular)
    }
}

// MARK: - Base Surfaces

struct IOSScreenBackground: View {
    var body: some View {
        IOSPalette.backgroundBase
            .ignoresSafeArea()
    }
}

struct IOSFlowlyHeader: View {
    let title: String
    var subtitle: String?
    var onBack: (() -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            IOSPalette.flowlyBlue
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.x3)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(IOSDesign.Typography.title)
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(IOSDesign.Typography.subtitle)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.x3)
                .padding(.bottom, Spacing.x3)
            }
        }
    }
}

struct IOSFlowlyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.x2)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.card, style: .continuous)
                    .fill(IOSPalette.backgroundLayer)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
    }
}

struct IOSCategoryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let pastelColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(pastelColor)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(IOSPalette.textPrimary)
            }
            Text(title)
                .font(IOSDesign.Typography.subtitle.weight(.semibold))
                .foregroundStyle(IOSPalette.textPrimary)
            Text(value)
                .font(IOSDesign.Typography.cardNumber)
                .foregroundStyle(IOSPalette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(IOSPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.x2)
        .background(
            RoundedRectangle(cornerRadius: IOSDesign.Radius.card, style: .continuous)
                .fill(pastelColor)
        )
    }
}

struct IOSProgressBar: View {
    let progress: Double
    var trackColor: Color = IOSPalette.progressTrack
    var fillColor: Color = IOSPalette.positive

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(trackColor)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(0, proxy.size.width * min(1, max(0, progress))))
            }
        }
    }
}

struct IOSSurfaceCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.x2)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.card, style: .continuous)
                    .fill(IOSPalette.backgroundLayer)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Buttons

struct IOSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(IOSPalette.accentGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
                    .shadow(
                        color: IOSPalette.accentA.opacity(configuration.isPressed ? 0.18 : 0.35),
                        radius: configuration.isPressed ? 7 : 14,
                        x: 0,
                        y: configuration.isPressed ? 3 : 8
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(IOSMotion.standard, value: configuration.isPressed)
    }
}

struct IOSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(IOSPalette.textPrimary)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(IOSPalette.backgroundLayer)
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .stroke(IOSPalette.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(IOSMotion.quick, value: configuration.isPressed)
    }
}

struct IOSOutlinedBlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(IOSPalette.flowlyBlue)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(IOSPalette.backgroundLayer)
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .stroke(IOSPalette.flowlyBlue, lineWidth: 2)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(IOSMotion.standard, value: configuration.isPressed)
    }
}

struct IOSInviteCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(IOSPalette.flowlyBlue)
                    .shadow(
                        color: IOSPalette.flowlyBlue.opacity(configuration.isPressed ? 0.3 : 0.4),
                        radius: configuration.isPressed ? 6 : 12,
                        x: 0,
                        y: configuration.isPressed ? 3 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(IOSMotion.emphasis, value: configuration.isPressed)
    }
}

// MARK: - Stat Card

struct IOSStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let accentColor: Color

    var body: some View {
        IOSSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title.uppercased())
                    .font(IOSDesign.Typography.section)
                    .foregroundStyle(IOSPalette.textSecondary)
                    .tracking(0.8)

                Text(value)
                    .font(IOSDesign.Typography.cardNumber)
                    .foregroundStyle(accentColor)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Chart Card

struct IOSChartCard: View {
    let title: String
    let subtitle: String
    let values: [Double]
    let accent: Color

    var body: some View {
        IOSSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(IOSDesign.Typography.body.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(IOSPalette.textSecondary)
                IOSMiniBarChart(values: values, accent: accent)
                    .frame(height: 120)
            }
        }
    }
}

struct IOSMiniBarChart: View {
    let values: [Double]
    let accent: Color

    private var normalized: [Double] {
        let maxValue = max(values.max() ?? 1, 1)
        return values.map { $0 / maxValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let count = max(values.count, 1)
            let spacing: CGFloat = 6
            let barWidth = max((width - spacing * CGFloat(count - 1)) / CGFloat(count), 6)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(normalized.enumerated()), id: \.offset) { index, item in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent)
                        .frame(width: barWidth, height: max(12, proxy.size.height * item))
                        .animation(IOSMotion.chartBars.delay(Double(index) * 0.04), value: values)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .animation(IOSMotion.standard, value: values)
        }
    }
}

struct IOSAnimatedAppear: ViewModifier {
    let index: Int
    let delayPerItem: Double

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(IOSMotion.appear.delay(delayPerItem * Double(index))) {
                    appeared = true
                }
            }
    }
}

extension View {
    func iosAnimatedAppear(index: Int = 0, delayPerItem: Double = 0.06) -> some View {
        modifier(IOSAnimatedAppear(index: index, delayPerItem: delayPerItem))
    }
}

// MARK: - Tag Chip

struct IOSTagChip: View {
    enum Style {
        case neutral, positive, negative, accent

        var foreground: Color {
            switch self {
            case .neutral: return IOSPalette.textSecondary
            case .positive: return IOSPalette.positive
            case .negative: return IOSPalette.negative
            case .accent: return IOSPalette.accentA
            }
        }

        var background: Color {
            switch self {
            case .neutral: return IOSPalette.backgroundElevated
            case .positive: return IOSPalette.positive.opacity(0.18)
            case .negative: return IOSPalette.negative.opacity(0.18)
            case .accent: return IOSPalette.accentA.opacity(0.18)
            }
        }
    }

    let text: String
    let style: Style
    var systemImage: String?
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(IOSDesign.Typography.badge)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(style.foreground)
        .background(
            Capsule(style: .continuous)
                .fill(style.background.opacity(isSelected ? 1.0 : 0.8))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(style.foreground.opacity(isSelected ? 0.5 : 0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Flowly Tab Bar

struct IOSFlowlyTabBar: View {
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Главная"),
        ("chart.bar.fill", "Операции"),
        ("gearshape.fill", "Ещё")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(IOSMotion.standard) {
                        onSelect(index)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .medium))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedIndex == index ? IOSPalette.flowlyBlue : IOSPalette.textSecondary)
                    .scaleEffect(selectedIndex == index ? 1.05 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(IOSMotion.standard, value: selectedIndex)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(IOSPalette.backgroundLayer)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }
}

// MARK: - Section Header

struct IOSSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(IOSDesign.Typography.section)
                    .foregroundStyle(IOSPalette.textSecondary)
                    .tracking(0.9)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary.opacity(0.9))
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.top, Spacing.unit)
    }
}

#endif

