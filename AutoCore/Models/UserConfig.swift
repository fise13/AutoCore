#if os(macOS)

import Foundation

struct UserConfig: Codable {
    var columns: [ColumnConfig]
    var dateFormat: String
    var useAutoDate: Bool
    var showSaleDate: Bool
    var businessType: BusinessType
}

struct ColumnConfig: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var type: ColumnType
    var isVisible: Bool
}

enum ColumnType: String, Codable {
    case text
    case number
    case date
}

enum BusinessType: String, Codable, CaseIterable, Identifiable {
    case warehouse
    case resale
    case custom

    var id: String { rawValue }
}

extension UserConfig {
    static func template(_ type: BusinessType) -> UserConfig {
        switch type {
        case .warehouse:
            return UserConfig(
                columns: [
                    .init(id: "engineNumber", title: "Номер двигателя", type: .text, isVisible: true),
                    .init(id: "configuration", title: "Комплектация", type: .text, isVisible: true),
                    .init(id: "quantity", title: "Кол-во", type: .number, isVisible: true),
                    .init(id: "arrivalDate", title: "Дата прихода", type: .date, isVisible: true),
                    .init(id: "soldDate", title: "Дата продажи", type: .date, isVisible: false),
                    .init(id: "notes", title: "Особые отметки", type: .text, isVisible: true),
                    .init(id: "transmission", title: "Коробка", type: .text, isVisible: true)
                ],
                dateFormat: "dd.MM.yyyy",
                useAutoDate: true,
                showSaleDate: false,
                businessType: .warehouse
            )
        case .resale:
            return UserConfig(
                columns: [
                    .init(id: "engineNumber", title: "Номер", type: .text, isVisible: true),
                    .init(id: "configuration", title: "Цена закупки", type: .number, isVisible: true),
                    .init(id: "notes", title: "Цена продажи", type: .number, isVisible: true),
                    .init(id: "soldDate", title: "Дата продажи", type: .date, isVisible: true),
                    .init(id: "arrivalDate", title: "Дата прихода", type: .date, isVisible: true),
                    .init(id: "quantity", title: "Кол-во", type: .number, isVisible: true),
                    .init(id: "transmission", title: "Коробка", type: .text, isVisible: true)
                ],
                dateFormat: "dd.MM.yyyy",
                useAutoDate: false,
                showSaleDate: true,
                businessType: .resale
            )
        case .custom:
            return UserConfig(
                columns: [
                    .init(id: "engineNumber", title: "Номер двигателя", type: .text, isVisible: true),
                    .init(id: "configuration", title: "Поле 1", type: .text, isVisible: true),
                    .init(id: "notes", title: "Поле 2", type: .text, isVisible: true),
                    .init(id: "quantity", title: "Количество", type: .number, isVisible: true),
                    .init(id: "arrivalDate", title: "Дата", type: .date, isVisible: true),
                    .init(id: "transmission", title: "Комментарий", type: .text, isVisible: true),
                    .init(id: "soldDate", title: "Дата продажи", type: .date, isVisible: false)
                ],
                dateFormat: "dd.MM.yyyy",
                useAutoDate: false,
                showSaleDate: true,
                businessType: .custom
            )
        }
    }
}

#endif
