//
//  Colors.swift
//  AutoCore
//
//  Design system colors — adaptive light/dark theme support.
//  Inspired by modern SaaS dashboards (Linear, Stripe, Vercel).
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DSColors {
    static let background = Color.dynamic(light: Color(hex: "F5F7FB"), dark: Color(hex: "0D0E12"))
    
    static let card = Color.dynamic(light: Color.white, dark: Color(hex: "161820"))
    
    static let accent = Color.dynamic(light: Color(hex: "0A73F2"), dark: Color(hex: "4D96FF"))
    
    static let textPrimary = Color.dynamic(light: Color(hex: "11131A"), dark: Color(hex: "F5F5F7"))
    
    static let textSecondary = Color.dynamic(light: Color(hex: "6E7480"), dark: Color(hex: "9498A4"))
    
    static let sidebarBackground = Color.dynamic(light: Color(hex: "EEF2F7"), dark: Color(hex: "12141A"))
    
    static let topBarBackground = Color.dynamic(light: Color(hex: "F1F4FA"), dark: Color(hex: "161820"))

    static let separator = Color.dynamic(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.06))
    
    static let positive = Color.dynamic(light: Color(hex: "26B34A"), dark: Color(hex: "40D168"))
    
    static let negative = Color.dynamic(light: Color(hex: "EB3838"), dark: Color(hex: "FF6166"))
    
    static let warning = Color.dynamic(light: Color(hex: "F0A500"), dark: Color(hex: "FFC94D"))

    static let info = Color.dynamic(light: Color(hex: "3390F0"), dark: Color(hex: "66B8FF"))
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
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
