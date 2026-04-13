#if os(macOS)

import SwiftUI

struct UserConfigOnboardingView: View {
    @StateObject private var viewModel = UserConfigOnboardingViewModel(store: .shared)
    var onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Первичная настройка")
                    .font(.title2.bold())
                Spacer()
                Text("Шаг \(viewModel.step)/\(viewModel.totalSteps)")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(viewModel.step), total: Double(viewModel.totalSteps))

            Group {
                switch viewModel.step {
                case 1: businessTypeStep
                case 2: columnsStep
                case 3: datesStep
                default: summaryStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Button("Назад") { viewModel.back() }
                    .disabled(!viewModel.canGoBack)
                Spacer()
                if viewModel.step < viewModel.totalSteps {
                    Button("Далее") { viewModel.next() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canGoForward)
                } else {
                    Button("Начать") {
                        viewModel.complete()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 440)
    }

    private var businessTypeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Выберите тип использования")
                .font(.headline)
            HStack(spacing: 12) {
                templateButton("Склад", type: .warehouse)
                templateButton("Перепродажа", type: .resale)
                templateButton("Своё", type: .custom)
            }
        }
    }

    private func templateButton(_ title: String, type: BusinessType) -> some View {
        let selected = viewModel.config.businessType == type
        return Button(title) {
            viewModel.selectBusinessType(type)
        }
        .buttonStyle(.borderedProminent)
        .tint(selected ? .accentColor : .gray.opacity(0.6))
    }

    private var columnsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройка колонок")
                .font(.headline)
            List {
                ForEach(viewModel.config.columns) { column in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { column.isVisible },
                            set: { viewModel.setColumnVisible($0, for: column.id) }
                        ))
                        .toggleStyle(.checkbox)
                        TextField("Название", text: Binding(
                            get: { column.title },
                            set: { viewModel.setColumnTitle($0, for: column.id) }
                        ))
                        Text(column.type.rawValue)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
            Text("Минимум одна колонка должна быть включена.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var datesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройка дат")
                .font(.headline)
            Picker("Формат", selection: Binding(
                get: { viewModel.config.dateFormat },
                set: { viewModel.setDateFormat($0) }
            )) {
                Text("DD.MM.YYYY").tag("dd.MM.yyyy")
                Text("MM/DD/YYYY").tag("MM/dd/yyyy")
            }
            .pickerStyle(.segmented)
            Toggle("Автоставить дату при создании", isOn: Binding(
                get: { viewModel.config.useAutoDate },
                set: { viewModel.setUseAutoDate($0) }
            ))
            Toggle("Показывать дату продажи", isOn: Binding(
                get: { viewModel.config.showSaleDate },
                set: { viewModel.setShowSaleDate($0) }
            ))
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Проверьте настройки")
                .font(.headline)
            Text("Тип: \(viewModel.config.businessType.rawValue)")
            Text("Формат даты: \(viewModel.config.dateFormat)")
            Text("Автодата: \(viewModel.config.useAutoDate ? "вкл" : "выкл")")
            Text("Дата продажи: \(viewModel.config.showSaleDate ? "показывать" : "скрыть")")

            Divider()
            Text("Колонки:")
                .font(.subheadline.bold())
            ForEach(viewModel.config.columns.filter(\.isVisible)) { column in
                Text("• \(column.title)")
            }
        }
    }
}

#endif
