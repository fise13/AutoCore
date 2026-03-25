//
//  Typography.swift
//  AutoCore
//
//  Custom design system typography
//

import SwiftUI

enum DSTypography {
    /// Section titles (e.g. "Сегодняшние продажи")
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    
    /// Body text
    static let body = Font.system(size: 14, weight: .regular)
    
    /// Large numbers for stat cards
    static let statValue = Font.system(size: 28, weight: .bold)
    
    /// Extra large stat value
    static let statValueLarge = Font.system(size: 32, weight: .bold)
    
    /// Caption / secondary text
    static let caption = Font.system(size: 12, weight: .regular)
    
    /// Small labels (uppercase section headers)
    static let label = Font.system(size: 11, weight: .semibold)
    
    /// Button text
    static let button = Font.system(size: 13, weight: .medium)
    
    /// Table/list header
    static let tableHeader = Font.system(size: 12, weight: .semibold)
}
