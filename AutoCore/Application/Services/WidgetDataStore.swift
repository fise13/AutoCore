//
//  WidgetDataStore.swift
//  AutoCore
//
//  Обмен данными между приложением и виджетом через App Group.
//  Приложение записывает, виджет читает.
//

import Foundation

#if os(iOS)

enum WidgetDataStore {
    static let appGroupId = "group.kz.autocore.accounting"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func save(cashBalance: Decimal, kaspiBalance: Decimal, updatedAt: Date = Date()) {
        defaults?.set(cashBalance as NSDecimalNumber, forKey: "cashBalance")
        defaults?.set(kaspiBalance as NSDecimalNumber, forKey: "kaspiBalance")
        defaults?.set(updatedAt, forKey: "updatedAt")
    }

    static func load() -> (cashBalance: Decimal, kaspiBalance: Decimal, updatedAt: Date?)? {
        guard let d = defaults,
              let cash = d.object(forKey: "cashBalance") as? NSDecimalNumber,
              let kaspi = d.object(forKey: "kaspiBalance") as? NSDecimalNumber else {
            return nil
        }
        return (cash as Decimal, kaspi as Decimal, d.object(forKey: "updatedAt") as? Date)
    }

    static func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return (formatter.string(from: value as NSDecimalNumber) ?? "0") + " ₸"
    }

    static func clear() {
        guard let d = defaults else { return }
        d.removeObject(forKey: "cashBalance")
        d.removeObject(forKey: "kaspiBalance")
        d.removeObject(forKey: "updatedAt")
        d.removeObject(forKey: "widgetData")
    }
}

#endif
