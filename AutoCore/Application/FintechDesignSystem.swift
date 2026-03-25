//
//  FintechDesignSystem.swift
//  AutoCore
//
//  Bold, layered fintech/trading-terminal aesthetic.
//  Multi-layer depth, dramatic lighting, rich surfaces. No Apple minimalism.
//

import SwiftUI

// MARK: - Typography (fintech scale)

enum FintechTypography {
    static let sectionTitle = Font.system(size: 13, weight: .bold)
    static let body = Font.system(size: 15, weight: .regular)
    static let emptyMessage = Font.system(size: 14, weight: .regular)
    static let emptyTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
}

// MARK: - Semantic Colors

enum FintechColors {
    /// Positive / income — vibrant neon green
    static let positive = Color(red: 0.15, green: 0.95, blue: 0.45)
    static let positiveGlow = Color(red: 0.2, green: 0.95, blue: 0.5).opacity(0.5)
    
    /// Negative / expense — glowing red
    static let negative = Color(red: 0.95, green: 0.25, blue: 0.3)
    static let negativeGlow = Color(red: 0.95, green: 0.3, blue: 0.35).opacity(0.5)
    
    /// Neutral / steel
    static let steel = Color.dynamic(light: Color(red: 0.38, green: 0.43, blue: 0.49), dark: Color(red: 0.45, green: 0.5, blue: 0.55))
    static let steelMuted = Color.dynamic(light: Color(red: 0.44, green: 0.47, blue: 0.53), dark: Color(red: 0.35, green: 0.38, blue: 0.42))
    
    /// Background layers (dark fintech base)
    static let backgroundDeep = Color.dynamic(light: Color(red: 0.95, green: 0.97, blue: 1.0), dark: Color(red: 0.08, green: 0.09, blue: 0.12))
    static let backgroundMid = Color.dynamic(light: Color(red: 0.93, green: 0.95, blue: 0.99), dark: Color(red: 0.11, green: 0.12, blue: 0.16))
    static let backgroundElevated = Color.dynamic(light: Color.white, dark: Color(red: 0.14, green: 0.15, blue: 0.19))
    static let backgroundHighlight = Color.dynamic(light: Color(red: 0.9, green: 0.93, blue: 0.98), dark: Color(red: 0.18, green: 0.19, blue: 0.24))
    
    /// Accent (cyan/teal terminal feel)
    static let accent = Color(red: 0.2, green: 0.75, blue: 0.85)
    static let accentGlow = Color(red: 0.25, green: 0.78, blue: 0.88).opacity(0.4)
}

// MARK: - Gradients

enum FintechGradients {
    /// Deep atmospheric background (multi-stop)
    static let environment = LinearGradient(
        colors: [
            FintechColors.backgroundDeep,
            FintechColors.backgroundMid,
            Color(red: 0.09, green: 0.10, blue: 0.14),
            FintechColors.backgroundDeep
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Secondary radial for depth
    static let environmentRadial = RadialGradient(
        colors: [
            FintechColors.backgroundMid.opacity(0.8),
            FintechColors.backgroundDeep
        ],
        center: .topLeading,
        startRadius: 0,
        endRadius: 1200
    )
    
    /// Panel surface (subtle gradient, not flat)
    static let panelFill = LinearGradient(
        colors: [
            FintechColors.backgroundElevated,
            FintechColors.backgroundMid
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Panel border (edge glow / lighting)
    static let panelBorder = LinearGradient(
        colors: [
            Color.dynamic(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.12)),
            Color.dynamic(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.04)),
            Color.dynamic(light: Color.black.opacity(0.02), dark: Color.white.opacity(0.02))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// KPI / stat block micro gradient
    static let kpiFill = LinearGradient(
        colors: [
            FintechColors.backgroundHighlight.opacity(0.6),
            FintechColors.backgroundElevated.opacity(0.8)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Positive gradient (neon green)
    static let positiveGradient = LinearGradient(
        colors: [FintechColors.positive, FintechColors.positive.opacity(0.75)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Negative gradient (red)
    static let negativeGradient = LinearGradient(
        colors: [FintechColors.negative, FintechColors.negative.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Chart area fill
    static let chartFill = LinearGradient(
        colors: [
            FintechColors.accent.opacity(0.35),
            FintechColors.accent.opacity(0.08),
            FintechColors.accent.opacity(0.02)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Shadow Layering

enum FintechShadows {
    static let panelDrop = Color.dynamic(light: Color.black.opacity(0.12), dark: Color.black.opacity(0.45))
    static let panelInner = Color.dynamic(light: Color.black.opacity(0.08), dark: Color.black.opacity(0.35))
    static let glowPositive = FintechColors.positiveGlow
    static let glowNegative = FintechColors.negativeGlow
    static let glowAccent = FintechColors.accentGlow
}

// MARK: - Fintech Panel (replaces glass cards)

struct FintechPanel<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var edgeGlowOpacity: Double = 0.35
    let content: Content
    
    init(cornerRadius: CGFloat = 16, edgeGlowOpacity: Double = 0.35, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.edgeGlowOpacity = edgeGlowOpacity
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(Spacing.x3)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FintechGradients.panelFill)
                    
                    // Inner shadow simulation (darker bottom edge)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(FintechShadows.panelInner, lineWidth: 1)
                        .blur(radius: 2)
                        .offset(y: 1)
                        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    
                    // Edge glow / top highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(FintechGradients.panelBorder, lineWidth: 1)
                    
                    // Subtle top-left highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(edgeGlowOpacity), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: FintechShadows.panelDrop, radius: 20, x: 0, y: 10)
            }
    }
}

// MARK: - Deep Gradient Background (environment)

struct FintechBackgroundView: View {
    var body: some View {
        ZStack {
            FintechGradients.environment
                .ignoresSafeArea()
            FintechGradients.environmentRadial
                .ignoresSafeArea()
        }
    }
}

// MARK: - KPI Block (framed stat module with glow edge)

struct FintechKPIBlock: View {
    let title: String
    let value: String
    let subtitle: String?
    let accent: KPIAccent
    
    enum KPIAccent {
        case positive, negative, neutral, accent
        var color: Color {
            switch self {
            case .positive: return FintechColors.positive
            case .negative: return FintechColors.negative
            case .neutral: return FintechColors.steel
            case .accent: return FintechColors.accent
            }
        }
        var glowColor: Color {
            switch self {
            case .positive: return FintechColors.positiveGlow
            case .negative: return FintechColors.negativeGlow
            case .neutral: return Color.clear
            case .accent: return FintechColors.accentGlow
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FintechColors.steelMuted)
                .textCase(.uppercase)
                .tracking(0.6)
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(accent.color)
                .shadow(color: accent.glowColor, radius: accent.glowColor == .clear ? 0 : 8)
            
            if let sub = subtitle {
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(FintechColors.steel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.x2)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FintechGradients.kpiFill)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                accent.color.opacity(0.25),
                                accent.color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
    }
}

// MARK: - Table Row Style (hover glow, depth)

struct FintechTableRowBackground: View {
    let isHovered: Bool
    let isHighlight: Bool
    
    init(isHovered: Bool = false, isHighlight: Bool = false) {
        self.isHovered = isHovered
        self.isHighlight = isHighlight
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                isHovered
                ? FintechColors.backgroundHighlight.opacity(0.8)
                : (isHighlight ? FintechColors.backgroundElevated.opacity(0.6) : Color.clear)
            )
            .overlay {
                if isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(FintechColors.accent.opacity(0.2), lineWidth: 1)
                }
            }
    }
}

// MARK: - Sidebar Rail (dimensional nav)

struct FintechSidebarRailStyle: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                        ? FintechColors.accent.opacity(0.2)
                        : (isHovered ? FintechColors.backgroundHighlight.opacity(0.5) : Color.clear)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? FintechColors.accent.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: isSelected ? FintechShadows.glowAccent.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 0
                    )
            }
    }
}

// MARK: - In-panel empty state (icon + message, for charts/lists)

struct FintechEmptyBlock: View {
    let icon: String
    let message: String
    var height: CGFloat = 120
    
    var body: some View {
        VStack(spacing: Spacing.x2) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(FintechColors.accent.opacity(0.8))
                .symbolRenderingMode(.hierarchical)
            Text(message)
                .font(FintechTypography.emptyMessage)
                .foregroundStyle(FintechColors.steel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

// MARK: - Bottom Tab Bar (fintech style, use in safeAreaInset)

#if os(iOS)
struct FintechTabBarItem: Identifiable {
    let id: Int
    let title: String
    let systemImage: String
}

struct FintechTabBar: View {
    let items: [FintechTabBarItem]
    @Binding var selection: Int
    
    private let cornerRadius: CGFloat = 22
    private let selectedBackgroundOpacity: Double = 0.2
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                FintechTabBarButton(
                    title: item.title,
                    systemImage: item.systemImage,
                    isSelected: selection == item.id,
                    selectedBackgroundOpacity: selectedBackgroundOpacity
                ) {
                    selection = item.id
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.top, Spacing.x2)
        .padding(.bottom, Spacing.x2)
        .background(barBackground)
    }
    
    private var barBackground: some View {
        ZStack {
            // Основа в стиле панели
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(FintechGradients.panelFill)
            
            // Граница по контуру
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(FintechGradients.panelBorder, lineWidth: 1)
            
            // Верхняя линия (отделение от контента)
            VStack {
                Rectangle()
                    .fill(Color.dynamic(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08)))
                    .frame(height: 1)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .shadow(color: Color.dynamic(light: Color.black.opacity(0.12), dark: Color.black.opacity(0.25)), radius: 12, x: 0, y: -2)
    }
}

private struct FintechTabBarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let selectedBackgroundOpacity: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                    .foregroundStyle(isSelected ? FintechColors.accent : FintechColors.steel)
                    .frame(height: 26)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? FintechColors.accent : FintechColors.steelMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.unit + 2)
            .padding(.horizontal, Spacing.unit)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? FintechColors.accent.opacity(selectedBackgroundOpacity) : Color.clear)
            )
        }
        .buttonStyle(FintechTabBarButtonStyle())
    }
}

private struct FintechTabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
#endif

// MARK: - Noise Overlay (optional texture)

struct NoiseOverlay: View {
    var opacity: Double = 0.03
    
    var body: some View {
        GeometryReader { g in
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height / 80) {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
