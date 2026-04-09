//
//  Shadows.swift
//  AutoCore
//
//  Adaptive shadow tokens — lighter in dark mode to avoid heavy appearance.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DSShadows {
    #if os(iOS)
    static let card = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.08)
    })
    #else
    static let card = Color.black.opacity(0.35)
    #endif
    static let cardRadius: CGFloat = 12
    static let cardX: CGFloat = 0
    static let cardY: CGFloat = 4

    #if os(iOS)
    static let elevated = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.55)
            : UIColor.black.withAlphaComponent(0.12)
    })
    #else
    static let elevated = Color.black.opacity(0.45)
    #endif
    static let elevatedRadius: CGFloat = 20
    static let elevatedY: CGFloat = 10
}
