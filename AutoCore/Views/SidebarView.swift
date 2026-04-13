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
    let onRenameBrand: (Int64, String) -> Void
    let onRenameCategory: (Int64, String) -> Void
    let onDeleteCategory: (Int64) -> Void
    let customization: SidebarCustomization

    @State private var expandedBrands: Set<Int64> = []
    @State private var hoveredItem: String? = nil
    @State private var brandToRename: Brand?
    @State private var renameBrandText = ""
    @State private var categoryToRename: DatabaseService.SpecificCategory?
    @State private var renameCategoryText = ""
    @State private var categoryToDelete: DatabaseService.SpecificCategory?

    private var enginesByBrand: [Int64: [Engine]] {
        Dictionary(grouping: engines, by: \.brandID)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Основные секции
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(customization.orderedSections.filter(customization.isVisible), id: \.self) { section in
                            SidebarButton(
                                title: section.title,
                                icon: section.icon,
                                isSelected: selectedSection.id == navigationSection(for: section).id,
                                hoveredItem: $hoveredItem,
                                action: {
                                    onSectionChange(navigationSection(for: section))
                                }
                            )
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                    
                    // Разделитель
                    SidebarDivider()
                        .padding(.vertical, 8)
                    
                    // Специфичные категории (динамические)
                    if customization.showSpecificCategories {
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
                                hoveredItem = hovering ? "add_category" : nil
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
                                        onSectionChange(.specificCategory(categoryID: category.id))
                                    }
                                )
                                .contextMenu {
                                    Button {
                                        categoryToRename = category
                                        renameCategoryText = category.name
                                    } label: {
                                        Label("Переименовать", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        categoryToDelete = category
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    }
                    
                    // Бренды (только для секции "Все")
                    if customization.showBrandsBlock && selectedSection.id == NavigationSection.all.id {
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
                                    onClearFilters()
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
                                        ForEach(enginesByBrand[brand.id] ?? []) { engine in
                                            SidebarButton(
                                                title: engine.code.uppercased(),
                                                icon: "gearshape.fill",
                                                isSelected: selectedEngineID == engine.id,
                                                indent: true,
                                                hoveredItem: $hoveredItem,
                                                action: {
                                                    onBrandAndEngineChange(brand.id, engine.id)
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
                                            expandedBrands.insert(brand.id)
                                            onBrandChange(brand.id)
                                        }
                                    )
                                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                                        brandToRename = brand
                                        renameBrandText = brand.name
                                    })
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
        .alert("Изменить бренд", isPresented: Binding(
            get: { brandToRename != nil },
            set: { if !$0 { brandToRename = nil } }
        )) {
            TextField("Новое имя бренда", text: $renameBrandText)
            Button("Отмена", role: .cancel) {
                brandToRename = nil
            }
            Button("Сохранить") {
                guard let brand = brandToRename else { return }
                let trimmed = renameBrandText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != brand.name else {
                    brandToRename = nil
                    return
                }
                onRenameBrand(brand.id, trimmed)
                brandToRename = nil
            }
        } message: {
            Text("Двойной клик по бренду открывает это окно редактирования.")
        }
        .alert("Изменить категорию", isPresented: Binding(
            get: { categoryToRename != nil },
            set: { if !$0 { categoryToRename = nil } }
        )) {
            TextField("Новое имя категории", text: $renameCategoryText)
            Button("Отмена", role: .cancel) {
                categoryToRename = nil
            }
            Button("Сохранить") {
                guard let category = categoryToRename else { return }
                let trimmed = renameCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != category.name else {
                    categoryToRename = nil
                    return
                }
                onRenameCategory(category.id, trimmed)
                categoryToRename = nil
            }
        } message: {
            Text("Категорию можно изменить через контекстное меню (правая кнопка мыши).")
        }
        .alert("Удалить категорию?", isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Отмена", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                guard let category = categoryToDelete else { return }
                onDeleteCategory(category.id)
                categoryToDelete = nil
            }
        } message: {
            Text("Будут удалены категория и её специфичные записи.")
        }
    }

    private func navigationSection(for section: SidebarBaseSection) -> NavigationSection {
        switch section {
        case .all: return .all
        case .sold: return .sold
        case .accounting: return .accounting
        case .warehouse: return .warehouse
        }
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
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItem = hovering ? itemID : nil
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
