//
//  SearchBar.swift
//  AutoCore
//
//  Dark styled search bar component
//

import SwiftUI

struct SearchBar: View {
    let placeholder: String
    @Binding var text: String
    
    init(placeholder: String = "Поиск...", text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(DSColors.textSecondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(DSColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DSColors.card)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
