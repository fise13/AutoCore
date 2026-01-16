import SwiftUI

struct ExportSelectionView: View {
    @Binding var isPresented: Bool
    let specificSheets: [DatabaseService.SpecificSheet]
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
                
                if specificSheets.isEmpty {
                    Text("Нет специфичных листов для выбора")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    Text("Выберите специфичные листы для экспорта:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(specificSheets, id: \.id) { sheet in
                                Toggle(isOn: Binding(
                                    get: { selectedSheetIDs.contains(sheet.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedSheetIDs.insert(sheet.id)
                                        } else {
                                            selectedSheetIDs.remove(sheet.id)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sheet.name)
                                            .font(.body)
                                        
                                        Text("Создан: \(formatDate(sheet.createdAt))")
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
                    let allIDs = Set(specificSheets.map { $0.id })
                    onExport(allIDs)
                    isPresented = false
                }
                .disabled(specificSheets.isEmpty)
                
                Button("Экспортировать выбранные") {
                    onExport(selectedSheetIDs)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSheetIDs.isEmpty && !specificSheets.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            // По умолчанию выбираем все
            selectedSheetIDs = Set(specificSheets.map { $0.id })
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}
