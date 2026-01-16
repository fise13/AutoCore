import SwiftUI
import AppKit

struct TesterWindowView: View {
    @StateObject var viewModel: TesterViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Панель тестировщика")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Закрыть") {
                    NSApplication.shared.keyWindow?.close()
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Статистика
                    GroupBox("Статистика базы данных") {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if let stats = viewModel.databaseStats {
                            VStack(alignment: .leading, spacing: 8) {
                                StatRow(label: "Бренды", value: "\(stats.brandsCount)")
                                StatRow(label: "Двигатели", value: "\(stats.enginesCount)")
                                StatRow(label: "Моторы", value: "\(stats.motorsCount)")
                                StatRow(label: "Проданные моторы", value: "\(stats.soldMotorsCount)")
                                StatRow(label: "Специфичные записи", value: "\(stats.serviceRecordsCount)")
                                StatRow(label: "Специфичные категории", value: "\(stats.specificCategoriesCount)")
                                StatRow(label: "Специфичные записи (новые)", value: "\(stats.specificRecordsCount)")
                                
                                if !stats.serviceRecordsByCategory.isEmpty {
                                    Divider()
                                    Text("По категориям:")
                                        .font(.headline)
                                    ForEach(Array(stats.serviceRecordsByCategory.sorted(by: { $0.key < $1.key })), id: \.key) { category, count in
                                        StatRow(label: category, value: "\(count)")
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .padding(8)
                        } else {
                            Text("Нажмите 'Обновить статистику'")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    
                    // Действия очистки
                    GroupBox("Очистка данных") {
                        VStack(spacing: 12) {
                            // Специфичные данные
                            GroupBox("Специфичные данные") {
                                VStack(spacing: 8) {
                                    TesterButton(
                                        title: "Удалить все специфичные категории",
                                        icon: "folder.fill",
                                        color: .orange,
                                        action: {
                                            viewModel.clearAllSpecificCategories()
                                        }
                                    )
                                    
                                    TesterButton(
                                        title: "Удалить все специфичные записи",
                                        icon: "doc.text",
                                        color: .orange,
                                        action: {
                                            viewModel.clearAllSpecificRecords()
                                        }
                                    )
                                    
                                    TesterButton(
                                        title: "Удалить старые специфичные записи",
                                        icon: "doc.text.below.ecg",
                                        color: .orange,
                                        action: {
                                            viewModel.clearAllServiceRecords()
                                        }
                                    )
                                }
                                .padding(4)
                            }
                            
                            Divider()
                            
                            // Основные данные
                            TesterButton(
                                title: "Удалить все моторы",
                                icon: "engine.combustion",
                                color: .red,
                                action: {
                                    viewModel.clearAllMotors()
                                }
                            )
                            
                            TesterButton(
                                title: "Удалить все двигатели",
                                icon: "gearshape",
                                color: .red,
                                action: {
                                    viewModel.clearAllEngines()
                                }
                            )
                            
                            TesterButton(
                                title: "Удалить все бренды",
                                icon: "tag",
                                color: .red,
                                action: {
                                    viewModel.clearAllBrands()
                                }
                            )
                            
                            Divider()
                            
                            TesterButton(
                                title: "Очистить всю базу данных",
                                icon: "trash.fill",
                                color: .red,
                                isDestructive: true,
                                action: {
                                    viewModel.clearAllData()
                                }
                            )
                        }
                        .padding(8)
                    }
                    
                    // Утилиты
                    GroupBox("Утилиты") {
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.refreshStats()
                            }) {
                                Label("Обновить статистику", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                let info = viewModel.exportDatabaseInfo()
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(info, forType: .string)
                            }) {
                                Label("Скопировать статистику", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Divider()
                            
                            Button(action: {
                                viewModel.optimizeDatabase()
                            }) {
                                Label("Оптимизировать базу данных", systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                viewModel.exportDatabaseBackup()
                            }) {
                                Label("Создать резервную копию", systemImage: "externaldrive.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                    }
                    
                    // Сообщения
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .background(.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if let success = viewModel.successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(success)
                                .foregroundStyle(.green)
                        }
                        .padding()
                        .background(.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            viewModel.refreshStats()
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

private struct TesterButton: View {
    let title: String
    let icon: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .foregroundStyle(isDestructive ? .white : .primary)
            .padding()
            .background(isDestructive ? color : color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
