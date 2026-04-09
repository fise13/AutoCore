//
//  Typography.swift
//  AutoCore
//
//  Design system typography — semantic text styles for macOS dashboard.
//

import SwiftUI

enum DSTypography {
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    static let statValue = Font.system(size: 28, weight: .bold)
    static let statValueLarge = Font.system(size: 32, weight: .bold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let label = Font.system(size: 11, weight: .semibold)
    static let button = Font.system(size: 13, weight: .medium)
    static let tableHeader = Font.system(size: 12, weight: .semibold)
    static let title = Font.system(size: 20, weight: .bold)
    static let headline = Font.system(size: 16, weight: .semibold)
}
