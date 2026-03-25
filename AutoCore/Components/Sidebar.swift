//
//  Sidebar.swift
//  AutoCore
//
//  Custom sidebar - 260pt width, dark background, icons + labels, active highlight, smooth hover
//

import SwiftUI

#if os(macOS)

struct Sidebar: View {
    let brands: [Brand]
    let engines: [Engine]
    let categories: [DatabaseService.SpecificCategory]
    let selectedSection: NavigationSection
    let selectedBrandID: Int64?
    let selectedEngineID: Int64?
    let onSectionChange: (NavigationSection) -> Void
    let onBrandChange: (Int64?) -> Void
    let onEngineChange: (Int64?) -> Void
    let onBrandAndEngineChange: (Int64?, Int64?) -> Void
    let onClearFilters: () -> Void
    let onCreateCategory: () -> Void

    @State private var expandedBrands: Set<Int64> = []
    @State private var hoveredItem: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Main sections
                    VStack(alignment: .leading, spacing: 4) {
                        SidebarItem(
                            title: NavigationSection.all.title,
                            icon: "list.bullet",
                            isSelected: selectedSection.id == NavigationSection.all.id,
                            hoveredItem: $hoveredItem,
                            action: { onSectionChange(.all) }
                        )
                        
                        SidebarItem(
                            title: NavigationSection.sold.title,
                            icon: "checkmark.seal.fill",
                            isSelected: selectedSection.id == NavigationSection.sold.id,
                            hoveredItem: $hoveredItem,
                            action: { onSectionChange(.sold) }
                        )
                        
                        SidebarItem(
                            title: NavigationSection.accounting.title,
                            icon: "dollarsign.circle.fill",
                            isSelected: selectedSection.id == NavigationSection.accounting.id,
                            hoveredItem: $hoveredItem,
                            action: { onSectionChange(.accounting) }
                        )

                        SidebarItem(
                            title: NavigationSection.warehouse.title,
                            icon: "shippingbox.fill",
                            isSelected: selectedSection.id == NavigationSection.warehouse.id,
                            hoveredItem: $hoveredItem,
                            action: { onSectionChange(.warehouse) }
                        )
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                    
                    SidebarDivider()
                        .padding(.vertical, 8)
                    
                    // Specific categories
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(L10n.Sidebar.specificSection)
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            Button(action: onCreateCategory) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(DSColors.accent)
                                    .symbolEffect(.bounce, value: hoveredItem == "add_category")
                            }
                            .buttonStyle(.plain)
                            .help(L10n.Sidebar.newCategoryHelp)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hoveredItem = hovering ? "add_category" : nil
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        if categories.isEmpty {
                            HStack {
                                Spacer().frame(width: 8)
                                Text(L10n.Sidebar.noCategories)
                                    .font(DSTypography.caption)
                                    .foregroundColor(DSColors.textSecondary)
                                    .italic()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                        } else {
                            ForEach(categories) { category in
                                SidebarItem(
                                    title: category.name,
                                    icon: "folder.fill",
                                    isSelected: selectedSection.categoryID == category.id,
                                    hoveredItem: $hoveredItem,
                                    action: { onSectionChange(.specificCategory(categoryID: category.id)) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // Brands (only when "All motors" selected)
                    if selectedSection.id == NavigationSection.all.id {
                        SidebarDivider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Sidebar.brands)
                                .font(DSTypography.label)
                                .foregroundColor(DSColors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            
                            SidebarItem(
                                title: L10n.Sidebar.allBrands,
                                icon: "tag.fill",
                                isSelected: selectedBrandID == nil && selectedEngineID == nil,
                                hoveredItem: $hoveredItem,
                                action: onClearFilters
                            )
                            
                            ForEach(brands) { brand in
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedBrands.contains(brand.id) },
                                        set: { isExpanded in
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if isExpanded {
                                                    expandedBrands.insert(brand.id)
                                                } else {
                                                    expandedBrands.remove(brand.id)
                                                }
                                            }
                                        }
                                    )
                                ) {
                                    VStack(spacing: 2) {
                                        ForEach(engines.filter { $0.brandID == brand.id }) { engine in
                                            SidebarItem(
                                                title: engine.code.uppercased(),
                                                icon: "gearshape.fill",
                                                isSelected: selectedEngineID == engine.id,
                                                indent: true,
                                                hoveredItem: $hoveredItem,
                                                action: { onBrandAndEngineChange(brand.id, engine.id) }
                                            )
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    SidebarItem(
                                        title: brand.name,
                                        icon: "car.fill",
                                        isSelected: selectedBrandID == brand.id && selectedEngineID == nil,
                                        hoveredItem: $hoveredItem,
                                        action: {
                                            expandedBrands.insert(brand.id)
                                            onBrandChange(brand.id)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 260)
        .background(DSColors.sidebarBackground)
        .tint(DSColors.accent)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var indent: Bool = false
    @Binding var hoveredItem: String?
    let action: () -> Void
    
    private var itemID: String { title }
    private var isHovered: Bool { hoveredItem == itemID }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if indent {
                    Spacer().frame(width: 20)
                }
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? DSColors.accent : (isHovered ? DSColors.textPrimary : DSColors.textSecondary))
                        .frame(width: 16)
                        .symbolEffect(.bounce, value: isSelected)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? DSColors.accent : DSColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? DSColors.accent.opacity(0.15)
                            : (isHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? DSColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredItem = hovering ? itemID : nil
            }
        }
    }
}

// MARK: - Sidebar Divider

private struct SidebarDivider: View {
    var body: some View {
        HStack {
            Spacer().frame(width: 8)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 8)
        }
    }
}

#endif
