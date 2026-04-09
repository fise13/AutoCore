import SwiftUI

#if os(iOS)
import UIKit

// MARK: - Adaptive Palette (Flowly)

enum IOSPalette {
    // MARK: Accent / Brand

    static let flowlyBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.56, blue: 1.0, alpha: 1)
            : UIColor(red: 0.04, green: 0.45, blue: 0.95, alpha: 1)
    })
    static let flowlyBlueDark = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.48, blue: 0.92, alpha: 1)
            : UIColor(red: 0.02, green: 0.35, blue: 0.82, alpha: 1)
    })
    static let flowlyBlueSubtle = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.22, blue: 0.38, alpha: 1)
            : UIColor(red: 0.90, green: 0.94, blue: 1.0, alpha: 1)
    })

    // MARK: Backgrounds

    static let backgroundBase = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
            : UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
    })
    static let backgroundLayer = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
            : UIColor.white
    })
    static let backgroundElevated = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
            : UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1)
    })
    static let backgroundGrouped = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
            : UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
    })

    // MARK: Text

    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    })
    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.58, green: 0.58, blue: 0.64, alpha: 1)
            : UIColor(red: 0.42, green: 0.42, blue: 0.48, alpha: 1)
    })
    static let textTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.42, blue: 0.48, alpha: 1)
            : UIColor(red: 0.60, green: 0.60, blue: 0.65, alpha: 1)
    })

    // MARK: Borders & Separators

    static let border = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor(red: 0.82, green: 0.82, blue: 0.86, alpha: 0.5)
    })
    static let separator = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.08)
    })

    // MARK: Semantic Accent Colors

    static let accentA = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.56, blue: 1.0, alpha: 1)
            : UIColor(red: 0.04, green: 0.45, blue: 0.95, alpha: 1)
    })
    static let accentB = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.48, blue: 0.92, alpha: 1)
            : UIColor(red: 0.02, green: 0.35, blue: 0.82, alpha: 1)
    })

    // MARK: Semantic Status Colors

    static let positive = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.82, blue: 0.45, alpha: 1)
            : UIColor(red: 0.15, green: 0.70, blue: 0.30, alpha: 1)
    })
    static let negative = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.38, blue: 0.42, alpha: 1)
            : UIColor(red: 0.92, green: 0.22, blue: 0.28, alpha: 1)
    })
    static let warning = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1)
            : UIColor(red: 0.95, green: 0.65, blue: 0.10, alpha: 1)
    })
    static let info = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1)
            : UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
    })

    // MARK: Category Pastel Tints

    static let houseOrange = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.22, blue: 0.14, alpha: 1)
            : UIColor(red: 1.0, green: 0.93, blue: 0.82, alpha: 1)
    })
    static let travelBlue = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.20, blue: 0.32, alpha: 1)
            : UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1)
    })
    static let shoppingPink = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.16, blue: 0.22, alpha: 1)
            : UIColor(red: 1.0, green: 0.92, blue: 0.94, alpha: 1)
    })
    static let healthGreen = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.28, blue: 0.20, alpha: 1)
            : UIColor(red: 0.88, green: 0.98, blue: 0.90, alpha: 1)
    })

    // MARK: Progress & Charts

    static let progressTrack = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
    })
    static let chartBar = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.56, blue: 1.0, alpha: 1)
            : UIColor(red: 0.04, green: 0.45, blue: 0.95, alpha: 1)
    })

    // MARK: Gradients

    static let screenGradient = LinearGradient(
        colors: [IOSPalette.backgroundBase, IOSPalette.backgroundLayer, IOSPalette.backgroundBase],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [IOSPalette.flowlyBlue, IOSPalette.flowlyBlueDark],
        startPoint: .leading,
        endPoint: .trailing
    )

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

    static let headerGradient = LinearGradient(
        colors: [IOSPalette.flowlyBlue, IOSPalette.flowlyBlueDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Motion

enum IOSMotion {
    static let quick = Animation.easeInOut(duration: 0.18)
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let emphasis = Animation.spring(response: 0.44, dampingFraction: 0.76)
    static let appear = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let chartBars = Animation.spring(response: 0.6, dampingFraction: 0.7)

    static func adaptiveAnimation(_ animation: Animation) -> Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .easeOut(duration: 0.01)
        }
        return animation
    }
}

// MARK: - Design Tokens

enum IOSDesign {
    enum Radius {
        static let chip: CGFloat = 999
        static let card: CGFloat = 20
        static let button: CGFloat = 16
        static let screenCard: CGFloat = 24
        static let input: CGFloat = 12
        static let badge: CGFloat = 8
    }

    enum Typography {
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 26, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 15, weight: .regular)
        static let section = Font.system(size: 12, weight: .semibold)
        static let badge = Font.system(size: 11, weight: .medium)
        static let number = Font.system(size: 28, weight: .bold, design: .rounded)
        static let cardNumber = Font.system(size: 22, weight: .bold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let caption = Font.system(size: 13, weight: .regular)
        static let footnote = Font.system(size: 12, weight: .regular)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Haptic Feedback

enum IOSHaptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Accessibility Metrics

enum IOSAccessibilityMetrics {
    static let minTouchTarget: CGFloat = 44
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
            IOSPalette.headerGradient
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(minWidth: IOSAccessibilityMetrics.minTouchTarget,
                                       minHeight: IOSAccessibilityMetrics.minTouchTarget)
                        }
                        .accessibilityLabel("Назад")
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
        .accessibilityValue("\(Int(progress * 100))%")
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
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Buttons

struct IOSPrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
            }
            configuration.label
        }
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
        .opacity(isLoading ? 0.85 : 1)
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

struct IOSDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(IOSPalette.negative)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                    .fill(IOSPalette.negative.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                            .stroke(IOSPalette.negative.opacity(0.3), lineWidth: 1)
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
                        .animation(
                            IOSMotion.adaptiveAnimation(IOSMotion.chartBars.delay(Double(index) * 0.04)),
                            value: values
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .animation(IOSMotion.adaptiveAnimation(IOSMotion.standard), value: values)
        }
    }
}

// MARK: - Animated Appear

struct IOSAnimatedAppear: ViewModifier {
    let index: Int
    let delayPerItem: Double

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (UIAccessibility.isReduceMotionEnabled ? 0 : 16))
            .onAppear {
                let animation = UIAccessibility.isReduceMotionEnabled
                    ? Animation.easeOut(duration: 0.12)
                    : IOSMotion.appear.delay(delayPerItem * Double(index))
                withAnimation(animation) {
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
        case neutral, positive, negative, accent, warning, info

        var foreground: Color {
            switch self {
            case .neutral: return IOSPalette.textSecondary
            case .positive: return IOSPalette.positive
            case .negative: return IOSPalette.negative
            case .accent: return IOSPalette.accentA
            case .warning: return IOSPalette.warning
            case .info: return IOSPalette.info
            }
        }

        var background: Color {
            switch self {
            case .neutral: return IOSPalette.backgroundElevated
            case .positive: return IOSPalette.positive.opacity(0.15)
            case .negative: return IOSPalette.negative.opacity(0.15)
            case .accent: return IOSPalette.accentA.opacity(0.15)
            case .warning: return IOSPalette.warning.opacity(0.15)
            case .info: return IOSPalette.info.opacity(0.15)
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
                        .stroke(style.foreground.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
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
                    IOSHaptics.selection()
                    withAnimation(IOSMotion.adaptiveAnimation(IOSMotion.standard)) {
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
                    .frame(minHeight: IOSAccessibilityMetrics.minTouchTarget)
                    .foregroundStyle(selectedIndex == index ? IOSPalette.flowlyBlue : IOSPalette.textSecondary)
                    .scaleEffect(selectedIndex == index ? 1.05 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
            }
        }
        .animation(IOSMotion.adaptiveAnimation(IOSMotion.standard), value: selectedIndex)
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

// MARK: - Empty State

struct IOSEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(IOSPalette.textTertiary)

            VStack(spacing: 6) {
                Text(title)
                    .font(IOSDesign.Typography.bodyMedium)
                    .foregroundStyle(IOSPalette.textPrimary)
                Text(message)
                    .font(IOSDesign.Typography.caption)
                    .foregroundStyle(IOSPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(IOSOutlinedBlueButtonStyle())
                .frame(width: 200)
            }
        }
        .padding(.vertical, Spacing.x3)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inline Status Banner

struct IOSStatusBanner: View {
    enum BannerType { case success, error, warning, info }

    let type: BannerType
    let message: String
    var onDismiss: (() -> Void)?

    private var icon: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch type {
        case .success: return IOSPalette.positive
        case .error: return IOSPalette.negative
        case .warning: return IOSPalette.warning
        case .info: return IOSPalette.info
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(message)
                .font(IOSDesign.Typography.caption)
                .foregroundStyle(IOSPalette.textPrimary)
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(IOSPalette.textSecondary)
                }
            }
        }
        .padding(Spacing.x2)
        .background(
            RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                .fill(tint.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Shimmer Loading Placeholder

struct IOSShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
            .fill(IOSPalette.backgroundElevated)
            .overlay(
                RoundedRectangle(cornerRadius: IOSDesign.Radius.input, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                IOSPalette.backgroundLayer.opacity(0.6),
                                Color.clear
                            ],
                            startPoint: .init(x: phase - 0.5, y: 0.5),
                            endPoint: .init(x: phase + 0.5, y: 0.5)
                        )
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

// MARK: - Skeleton Loading Card

struct IOSSkeletonCard: View {
    var lineCount: Int = 3

    var body: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: 12) {
                IOSShimmerView()
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                ForEach(0..<lineCount, id: \.self) { i in
                    IOSShimmerView()
                        .frame(height: 12)
                        .frame(maxWidth: i == lineCount - 1 ? 180 : .infinity)
                }
            }
        }
    }
}

// MARK: - Sync Status Indicator

struct IOSSyncStatusView: View {
    enum SyncState { case synced, syncing, offline, error }

    let state: SyncState

    private var config: (icon: String, text: String, color: Color) {
        switch state {
        case .synced: return ("checkmark.icloud.fill", "Синхронизировано", IOSPalette.positive)
        case .syncing: return ("arrow.triangle.2.circlepath.icloud.fill", "Синхронизация…", IOSPalette.info)
        case .offline: return ("icloud.slash.fill", "Офлайн", IOSPalette.warning)
        case .error: return ("exclamationmark.icloud.fill", "Ошибка синхронизации", IOSPalette.negative)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: config.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(config.color)
            Text(config.text)
                .font(IOSDesign.Typography.footnote)
                .foregroundStyle(config.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(config.color.opacity(0.1))
        )
    }
}

#endif
