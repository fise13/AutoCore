//
//  Shadows.swift
//  AutoCore
//
//  Custom design system shadows
//

import SwiftUI

enum DSShadows {
    /// Card shadow - subtle elevation
    static let card = Color.black.opacity(0.35)
    static let cardRadius: CGFloat = 12
    static let cardX: CGFloat = 0
    static let cardY: CGFloat = 4
    
    /// Stronger elevation for modals/overlays
    static let elevated = Color.black.opacity(0.45)
    static let elevatedRadius: CGFloat = 20
    static let elevatedY: CGFloat = 10
}
