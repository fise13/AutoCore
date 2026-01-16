import SwiftUI

struct ExportSelectionView: View {
    @Binding var isPresented: Bool
    let specificCategories: [DatabaseService.SpecificCategory]
    let onExport: (Set<Int64>) -> Void
    
    @State private var selectedSheetIDs: Set<Int64> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("Выбор листов для экспорта")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Отмена") {
                    isPresented = false
                }
            }
            .padding()
            
            Divider()
            
            // Контент
            VStack(alignment: .leading, spacing: 16) {
                Text("Все листы двигателей будут экспортированы автоматически.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top)
                
                if specificCategories.isEmpty {
                    Text("Нет специфичных категорий для выбора")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    Text("Выберите специфичные категории для экспорта:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(specificCategories, id: \.id) { category in
                                Toggle(isOn: Binding(
                                    get: { selectedSheetIDs.contains(category.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedSheetIDs.insert(category.id)
                                        } else {
                                            selectedSheetIDs.remove(category.id)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(category.name)
                                            .font(.body)
                                        
                                        Text("Создан: \(formatDate(category.createdAt))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            
            Divider()
            
            // Кнопки
            HStack {
                Spacer()
                
                Button("Экспортировать все") {
                    let allIDs = Set(specificCategories.map { $0.id })
                    onExport(allIDs)
                    isPresented = false
                }
                .disabled(specificCategories.isEmpty)
                
                Button("Экспортировать выбранные") {
                    onExport(selectedSheetIDs)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSheetIDs.isEmpty && !specificCategories.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            // По умолчанию выбираем все
            selectedSheetIDs = Set(specificCategories.map { $0.id })
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
