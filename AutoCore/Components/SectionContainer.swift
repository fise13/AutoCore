//
//  SectionContainer.swift
//  AutoCore
//
//  Wrapper for content sections with consistent padding and background
//

import SwiftUI

struct SectionContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DSSpacing.x3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColors.card)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: DSShadows.card, radius: DSShadows.cardRadius, x: DSShadows.cardX, y: DSShadows.cardY)
    }
}
