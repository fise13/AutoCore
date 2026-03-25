//
//  WidgetDataWriter.swift
//  AutoCore
//
//  Записывает данные для виджетов в App Group. Вызывается при обновлении dashboard.
//

import Foundation
import WidgetKit

#if os(iOS)

struct TodaySpendingPayload: Codable {
    let food: Double
    let transport: Double
    let shopping: Double
    let other: Double
}

enum WidgetDataWriter {
    static let appGroupId = "group.kz.autocore.accounting"

    struct Payload: Codable {
        let cashBalance: Double
        let kaspiBalance: Double
        let dailyTotals: [Double]
        let todaySpending: TodaySpendingPayload?
        let updatedAt: Date
    }

    /// Записать данные для виджетов. Вызывать при обновлении cashBalance, kaspiBalance, dailyTotals, todaySpending.
    static func write(
        cashBalance: Decimal,
        kaspiBalance: Decimal,
        dailyTotals: [Double],
        todaySpending: TodaySpendingPayload? = nil
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            #if DEBUG
            print("WidgetDataWriter: App Group '\(appGroupId)' unavailable. Check that AutoCoreAccounting.entitlements includes this group.")
            #endif
            return
        }
        let payload = Payload(
            cashBalance: NSDecimalNumber(decimal: cashBalance).doubleValue,
            kaspiBalance: NSDecimalNumber(decimal: kaspiBalance).doubleValue,
            dailyTotals: dailyTotals,
            todaySpending: todaySpending,
            updatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: "widgetData")
        defaults.synchronize()
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
    }
}

#endif
