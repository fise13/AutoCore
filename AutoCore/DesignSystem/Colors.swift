//
//  Colors.swift
//  AutoCore
//
//  Custom design system colors - SaaS dashboard aesthetic (Linear, Stripe, Vercel)
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DSColors {
    /// Main app background
    static let background = Color.dynamic(light: Color(hex: "F5F7FB"), dark: Color(hex: "0F1115"))
    
    /// Card and elevated surface background
    static let card = Color.dynamic(light: Color.white, dark: Color(hex: "171A21"))
    
    /// Primary accent - buttons, links, active states
    static let accent = Color(hex: "4C8BF5")
    
    /// Primary text
    static let textPrimary = Color.dynamic(light: Color(hex: "11131A"), dark: Color.white)
    
    /// Secondary/muted text
    static let textSecondary = Color.dynamic(light: Color(hex: "6E7480"), dark: Color(hex: "8B8F98"))
    
    /// Sidebar background (slightly darker than card)
    static let sidebarBackground = Color.dynamic(light: Color(hex: "EEF2F7"), dark: Color(hex: "14171E"))
    
    /// Top bar background
    static let topBarBackground = Color.dynamic(light: Color(hex: "F1F4FA"), dark: Color(hex: "171A21"))

    /// Universal subtle separator
    static let separator = Color.dynamic(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.06))
    
    /// Positive/income (green)
    static let positive = Color(hex: "34C759")
    
    /// Negative/expense (red)
    static let negative = Color(hex: "FF3B30")
    
    /// Warning (orange)
    static let warning = Color(hex: "FF9500")
}

// MARK: - Color Hex Extension

extension Color {
    static func dynamic(light: Color, dark: Color) -> Color {
        #if os(iOS)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return dark
        #endif
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
