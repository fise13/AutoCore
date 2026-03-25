//
//  StatCard.swift
//  AutoCore
//
//  Dashboard stat card - rounded 16, dark background, large number typography
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var valueColor: Color = DSColors.textPrimary
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.unit) {
            Text(title)
                .font(DSTypography.sectionTitle)
                .foregroundColor(DSColors.textSecondary)
            
            Text(value)
                .font(DSTypography.statValue)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.x3)
        .background(DSColors.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: DSShadows.card, radius: DSShadows.cardRadius, x: DSShadows.cardX, y: DSShadows.cardY)
    }
}
