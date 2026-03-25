//
//  AutoCoreAccountingWidgets.swift
//  AutoCoreAccountingWidgets
//
//  Виджеты для главного экрана: денежная позиция, касса, Kaspi.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data (читаем из App Group)

private enum WidgetData {
    static let appGroupId = "group.wise.AutoCoreAccounting"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func load() -> (cashBalance: Decimal, kaspiBalance: Decimal)? {
        guard let d = defaults,
              let cash = d.object(forKey: "cashBalance") as? NSDecimalNumber,
              let kaspi = d.object(forKey: "kaspiBalance") as? NSDecimalNumber else {
            return nil
        }
        return (cash as Decimal, kaspi as Decimal)
    }

    static func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return (formatter.string(from: value as NSDecimalNumber) ?? "0") + " ₸"
    }
}

// MARK: - Entry

struct BalanceEntry: TimelineEntry {
    let date: Date
    let cashBalance: Decimal
    let kaspiBalance: Decimal
}

// MARK: - Provider

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: Date(), cashBalance: 0, kaspiBalance: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        if let data = WidgetData.load() {
            completion(BalanceEntry(date: Date(), cashBalance: data.cashBalance, kaspiBalance: data.kaspiBalance))
        } else {
            completion(BalanceEntry(date: Date(), cashBalance: 0, kaspiBalance: 0))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        if let data = WidgetData.load() {
            let entry = BalanceEntry(date: Date(), cashBalance: data.cashBalance, kaspiBalance: data.kaspiBalance)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        } else {
            let entry = BalanceEntry(date: Date(), cashBalance: 0, kaspiBalance: 0)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60))))
        }
    }
}

// MARK: - Views

struct SmallBalanceView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "building.columns.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.04, green: 0.52, blue: 1), Color(red: 0.08, green: 0.45, blue: 0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("AutoCore")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(WidgetData.format(entry.cashBalance + entry.kaspiBalance))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Денежная позиция")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

struct MediumBalanceView: View {
    let entry: BalanceEntry

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "building.columns.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.04, green: 0.52, blue: 1), Color(red: 0.08, green: 0.45, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("AutoCore Accounting")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Text(WidgetData.format(entry.cashBalance + entry.kaspiBalance))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Денежная позиция")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Касса")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(WidgetData.format(entry.cashBalance))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Kaspi")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(WidgetData.format(entry.kaspiBalance))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Widget

@main
struct AutoCoreAccountingWidgets: Widget {
    let kind: String = "AutoCoreAccountingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetView(entry: entry)
                    .padding()
                    .background(Color(.systemBackground))
            }
        }
        .configurationDisplayName("Денежная позиция")
        .description("Баланс кассы и Kaspi на главном экране")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: BalanceEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallBalanceView(entry: entry)
        case .systemMedium:
            MediumBalanceView(entry: entry)
        default:
            SmallBalanceView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AutoCoreAccountingWidgets()
} timeline: {
    BalanceEntry(date: Date(), cashBalance: 1_250_000, kaspiBalance: 580_000)
}
