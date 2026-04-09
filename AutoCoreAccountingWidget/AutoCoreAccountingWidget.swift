//
//  AutoCoreAccountingWidget.swift
//  AutoCoreAccountingWidget
//
//  Виджеты: малый — расходы по категориям (pie), средний — столбчатая диаграмма,
//  большой — полная сводка, lock screen — краткая позиция.
//

import WidgetKit
import SwiftUI
import Charts

// MARK: - Shared Data (читается из App Group)

struct TodaySpending: Codable, Equatable {
    let food: Double
    let transport: Double
    let shopping: Double
    let other: Double

    var total: Double { food + transport + shopping + other }

    static let empty = TodaySpending(food: 0, transport: 0, shopping: 0, other: 0)
}

struct WidgetData: Codable {
    let cashBalance: Double
    let kaspiBalance: Double
    let dailyTotals: [Double]
    let todaySpending: TodaySpending?
    let updatedAt: Date

    var totalBalance: Double { cashBalance + kaspiBalance }

    init(cashBalance: Double, kaspiBalance: Double, dailyTotals: [Double], todaySpending: TodaySpending? = nil, updatedAt: Date) {
        self.cashBalance = cashBalance
        self.kaspiBalance = kaspiBalance
        self.dailyTotals = dailyTotals
        self.todaySpending = todaySpending
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cashBalance = try c.decode(Double.self, forKey: .cashBalance)
        kaspiBalance = try c.decode(Double.self, forKey: .kaspiBalance)
        dailyTotals = try c.decode([Double].self, forKey: .dailyTotals)
        todaySpending = try c.decodeIfPresent(TodaySpending.self, forKey: .todaySpending)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    static let placeholder = WidgetData(
        cashBalance: 0,
        kaspiBalance: 0,
        dailyTotals: [0, 0, 0, 0, 0, 0, 0],
        todaySpending: .empty,
        updatedAt: Date()
    )
}

enum WidgetDataStore {
    static let appGroupId = "group.kz.autocore.accounting"

    static func load() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return nil
        }
        if let data = defaults.data(forKey: "widgetData"),
           let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) {
            return decoded
        }
        // Fallback для старого формата, где значения писались отдельными ключами.
        let cash = defaults.object(forKey: "cashBalance") as? NSNumber
        let kaspi = defaults.object(forKey: "kaspiBalance") as? NSNumber
        if let cash, let kaspi {
            return WidgetData(
                cashBalance: cash.doubleValue,
                kaspiBalance: kaspi.doubleValue,
                dailyTotals: Array(repeating: 0, count: 7),
                todaySpending: .empty,
                updatedAt: defaults.object(forKey: "updatedAt") as? Date ?? Date()
            )
        }
        return nil
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry: WidgetEntry
        if let data = WidgetDataStore.load() {
            entry = WidgetEntry(date: Date(), data: data)
        } else {
            entry = placeholder(in: context)
        }
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let now = Date()
        let data = WidgetDataStore.load() ?? .placeholder
        let entry = WidgetEntry(date: now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Adaptive Colors

private enum WColors {
    static let accent = Color(red: 0.04, green: 0.45, blue: 0.95)
    static let accentLight = Color(red: 0.30, green: 0.56, blue: 1.0)
    static let positive = Color(red: 0.15, green: 0.70, blue: 0.30)
    static let food = Color(red: 0.31, green: 0.55, blue: 0.99)
    static let transport = Color(red: 0.43, green: 0.84, blue: 0.63)
    static let shopping = Color(red: 0.97, green: 0.79, blue: 0.28)
    static let other = Color(red: 1.0, green: 0.48, blue: 0.48)
}

// MARK: - Daily Expense Widget (Pie Chart - Small)

struct DailyExpenseWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: WidgetEntry

    private var spending: TodaySpending {
        entry.data.todaySpending ?? .empty
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("Сегодня")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Chart(spending.chartSegments) { seg in
                SectorMark(
                    angle: .value("Amount", seg.value),
                    innerRadius: .ratio(0.6),
                    angularInset: 1
                )
                .foregroundStyle(seg.color)
            }
            .chartLegend(.hidden)
            .frame(width: 88, height: 88)

            Text(formatCurrency(spending.total))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Расходы")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))
        }
    }
}

// MARK: - Medium Widget (Bar Chart + Balance)

struct MediumWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: WidgetEntry

    private var total: Double { entry.data.totalBalance }

    private var normalizedBars: [Double] {
        let values = entry.data.dailyTotals
        let maxVal = max(values.max() ?? 1, 1)
        return values.map { $0 / maxVal }
    }

    private var dayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru")
        formatter.dateFormat = "EEE"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: today) }
            .map { formatter.string(from: $0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "building.columns.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(WColors.accent)
                    Text("AutoCore")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text(formatCurrency(total))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle().fill(WColors.positive).frame(width: 6, height: 6)
                        Text("Касса: \(formatCurrency(entry.data.cashBalance))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(WColors.accent).frame(width: 6, height: 6)
                        Text("Kaspi: \(formatCurrency(entry.data.kaspiBalance))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GeometryReader { geo in
                let h = geo.size.height
                let count = max(normalizedBars.count, 1)
                let spacing: CGFloat = 4
                let barW = max((geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 3)

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(normalizedBars.enumerated()), id: \.offset) { i, val in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(WColors.accent.opacity(0.8))
                                .frame(width: barW, height: max(3, h * 0.7 * val))
                            Text(dayLabels.indices.contains(i) ? dayLabels[i] : "")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))
        }
    }
}

// MARK: - Large Widget (Full Summary)

struct LargeWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: WidgetEntry

    private var total: Double { entry.data.totalBalance }
    private var spending: TodaySpending { entry.data.todaySpending ?? .empty }

    private var normalizedBars: [Double] {
        let values = entry.data.dailyTotals
        let maxVal = max(values.max() ?? 1, 1)
        return values.map { $0 / maxVal }
    }

    private var dayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru")
        formatter.dateFormat = "EEE"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: today) }
            .map { formatter.string(from: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(WColors.accent)
                        Text("AutoCore")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Text("\(formatCurrency(total)) ₸")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    legendDot(color: WColors.positive, label: "Касса", value: formatCurrency(entry.data.cashBalance))
                    legendDot(color: WColors.accent, label: "Kaspi", value: formatCurrency(entry.data.kaspiBalance))
                }
            }

            GeometryReader { geo in
                let h = geo.size.height
                let count = max(entry.data.dailyTotals.count, 1)
                let spacing: CGFloat = 6
                let barW = max((geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 4)

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(normalizedBars.enumerated()), id: \.offset) { i, val in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(WColors.accent)
                                .frame(width: barW, height: max(4, h * 0.7 * val))
                            Text(dayLabels.indices.contains(i) ? dayLabels[i] : "")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 70)

            HStack(spacing: 12) {
                spendingChip(icon: "fork.knife", label: "Еда", value: spending.food, color: WColors.food)
                spendingChip(icon: "car.fill", label: "Транспорт", value: spending.transport, color: WColors.transport)
                spendingChip(icon: "bag.fill", label: "Покупки", value: spending.shopping, color: WColors.shopping)
                spendingChip(icon: "ellipsis", label: "Прочее", value: spending.other, color: WColors.other)
            }

            Text("Обновлено: \(timeAgoString(entry.data.updatedAt))")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))
        }
    }

    private func legendDot(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label): \(value)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func spendingChip(icon: String, label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
            Text(formatCompact(value))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func timeAgoString(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "только что" }
        if minutes < 60 { return "\(minutes) мин назад" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) ч назад" }
        return "\(hours / 24) дн назад"
    }
}

// MARK: - Lock Screen Widget (Accessory)

struct AccessoryBalanceView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 10, weight: .medium))
            Text(formatCompact(entry.data.totalBalance))
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text("₸")
                .font(.system(size: 8, weight: .medium))
        }
    }
}

struct AccessoryInlineBalanceView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "building.columns.fill")
            Text("\(formatCompact(entry.data.totalBalance)) ₸")
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

// MARK: - Chart Helpers

private struct ChartSegment: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
}

extension TodaySpending {
    static let mock = TodaySpending(food: 4200, transport: 1800, shopping: 3500, other: 2950)

    fileprivate var chartSegments: [ChartSegment] {
        let segments = [
            ChartSegment(value: food, color: WColors.food),
            ChartSegment(value: transport, color: WColors.transport),
            ChartSegment(value: shopping, color: WColors.shopping),
            ChartSegment(value: other, color: WColors.other)
        ].filter { $0.value > 0 }
        if segments.isEmpty {
            return [ChartSegment(value: 1, color: Color.gray.opacity(0.3))]
        }
        return segments
    }
}

// MARK: - Formatting Helpers

private func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

private func formatCompact(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "%.0fK", value / 1_000)
    }
    return String(format: "%.0f", value)
}

// MARK: - Widget Entry View

struct AutoCoreAccountingWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            DailyExpenseWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryBalanceView(entry: entry)
        case .accessoryInline:
            AccessoryInlineBalanceView(entry: entry)
        default:
            DailyExpenseWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct AutoCoreAccountingWidget: Widget {
    let kind: String = "AutoCoreAccountingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AutoCoreAccountingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AutoCore")
        .description("Касса, Kaspi и динамика операций.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    AutoCoreAccountingWidget()
} timeline: {
    WidgetEntry(
        date: Date(),
        data: WidgetData(
            cashBalance: 500_000,
            kaspiBalance: 300_000,
            dailyTotals: [12000, 25000, 18000, 32000, 15000, 28000, 22000],
            todaySpending: .mock,
            updatedAt: Date()
        )
    )
}
