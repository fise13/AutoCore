import SwiftUI

struct SidebarView: View {
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
                    // Основные секции
                    VStack(alignment: .leading, spacing: 4) {
                        SidebarButton(
                            title: NavigationSection.all.title,
                            icon: "list.bullet",
                            isSelected: selectedSection.id == NavigationSection.all.id,
                            hoveredItem: $hoveredItem,
                            action: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                    onSectionChange(.all)
                                }
                            }
                        )
                        
                        SidebarButton(
                            title: NavigationSection.sold.title,
                            icon: "checkmark.seal.fill",
                            isSelected: selectedSection.id == NavigationSection.sold.id,
                            hoveredItem: $hoveredItem,
                            action: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                    onSectionChange(.sold)
                                }
                            }
                        )
                        
                        SidebarButton(
                            title: NavigationSection.accounting.title,
                            icon: "dollarsign.circle.fill",
                            isSelected: selectedSection.id == NavigationSection.accounting.id,
                            hoveredItem: $hoveredItem,
                            action: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                    onSectionChange(.accounting)
                                }
                            }
                        )
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                    
                    // Разделитель
                    SidebarDivider()
                        .padding(.vertical, 8)
                    
                    // Специфичные категории (динамические)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Специфичные")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            Button(action: onCreateCategory) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                                    .symbolEffect(.bounce, value: hoveredItem == "add_category")
                            }
                            .buttonStyle(.plain)
                            .help("Новая категория")
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
                                Spacer()
                                    .frame(width: 8)
                                Text("Нет категорий")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                        } else {
                            ForEach(categories) { category in
                                SidebarButton(
                                    title: category.name,
                                    icon: "folder.fill",
                                    isSelected: selectedSection.categoryID == category.id,
                                    hoveredItem: $hoveredItem,
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                            onSectionChange(.specificCategory(categoryID: category.id))
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // Бренды (только для секции "Все")
                    if selectedSection.id == NavigationSection.all.id {
                        SidebarDivider()
                            .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Бренды")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            
                            SidebarButton(
                                title: "Все бренды",
                                icon: "tag.fill",
                                isSelected: selectedBrandID == nil && selectedEngineID == nil,
                                hoveredItem: $hoveredItem,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                        onClearFilters()
                                    }
                                }
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
                                            SidebarButton(
                                                title: engine.code.uppercased(),
                                                icon: "gearshape.fill",
                                                isSelected: selectedEngineID == engine.id,
                                                indent: true,
                                                hoveredItem: $hoveredItem,
                                                action: {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                                        onBrandAndEngineChange(brand.id, engine.id)
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    SidebarButton(
                                        title: brand.name,
                                        icon: "car.fill",
                                        isSelected: selectedBrandID == brand.id && selectedEngineID == nil,
                                        hoveredItem: $hoveredItem,
                                        action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                expandedBrands.insert(brand.id)
                                                // Вызываем напрямую, так как мы уже на MainActor в SwiftUI View
                                                onBrandChange(brand.id)
                                            }
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
        .frame(width: 240)
        .background {
            ZStack {
                // Основной фон
                Color(NSColor.controlBackgroundColor)
                
                // Градиент для глубины
                LinearGradient(
                    colors: [
                        Color(NSColor.controlBackgroundColor),
                        Color(NSColor.controlBackgroundColor).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .overlay(
            // Правая граница с тенью
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(NSColor.separatorColor).opacity(0.3),
                            Color(NSColor.separatorColor)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 1)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 0),
            alignment: .trailing
        )
    }
}

// MARK: - Sidebar Button

private struct SidebarButton: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var indent: Bool = false
    @Binding var hoveredItem: String?
    let action: () -> Void
    
    private var itemID: String {
        title
    }
    
    private var isHovered: Bool {
        hoveredItem == itemID
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if indent {
                    Spacer()
                        .frame(width: 20)
                }
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .accentColor : (isHovered ? .primary : .secondary))
                        .frame(width: 16)
                        .symbolEffect(.bounce, value: isSelected)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected 
                            ? Color.accentColor.opacity(0.15)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
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
            Spacer()
                .frame(width: 8)
            Rectangle()
                .fill(Color(NSColor.separatorColor).opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 8)
        }
    }
}
