//
//  AutoCoreAccountingWidget.swift
//  AutoCoreAccountingWidget
//
//  Виджеты: малый — расходы по категориям (pie), большой — столбчатая диаграмма.
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
}

enum WidgetDataStore {
    static let appGroupId = "group.kz.autocore.accounting"

    static func load() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "widgetData"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            data: WidgetData(
                cashBalance: 0,
                kaspiBalance: 0,
                dailyTotals: [0, 0, 0, 0, 0, 0, 0],
                todaySpending: .empty,
                updatedAt: Date()
            )
        )
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
        let data = WidgetDataStore.load() ?? WidgetData(
            cashBalance: 0,
            kaspiBalance: 0,
            dailyTotals: [0, 0, 0, 0, 0, 0, 0],
            todaySpending: .empty,
            updatedAt: now
        )
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

// MARK: - Daily Expense Widget (Pie Chart)

private let expenseColors = (
    food: Color(hex: "#4F8DFD"),
    transport: Color(hex: "#6ED6A0"),
    shopping: Color(hex: "#F7C948"),
    other: Color(hex: "#FF7A7A")
)

struct DailyExpenseWidgetView: View {
    let entry: WidgetEntry

    private var spending: TodaySpending {
        entry.data.todaySpending ?? .empty
    }

    private var widgetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.12, blue: 0.18),
                Color(red: 0.08, green: 0.1, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("Сегодня")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

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
                .foregroundStyle(.white)

            Text("Расходы")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(widgetGradient)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return "₸\(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }
}

// MARK: - TodaySpending Chart Helpers

private struct ChartSegment: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
}

extension TodaySpending {
    static let mock = TodaySpending(
        food: 4200,
        transport: 1800,
        shopping: 3500,
        other: 2950
    )

    fileprivate var chartSegments: [ChartSegment] {
        let segments = [
            ChartSegment(value: food, color: expenseColors.food),
            ChartSegment(value: transport, color: expenseColors.transport),
            ChartSegment(value: shopping, color: expenseColors.shopping),
            ChartSegment(value: other, color: expenseColors.other)
        ].filter { $0.value > 0 }
        if segments.isEmpty {
            return [ChartSegment(value: 1, color: Color.white.opacity(0.2))]
        }
        return segments
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Large Widget (Full Bar Chart)

struct LargeWidgetView: View {
    let entry: WidgetEntry

    private var total: Double {
        entry.data.cashBalance + entry.data.kaspiBalance
    }

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

    private var widgetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.12, blue: 0.18),
                Color(red: 0.08, green: 0.1, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AutoCore")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(formatCurrency(total)) ₸")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        legendDot(color: Color(red: 1, green: 0.92, blue: 0.6), label: "Касса")
                        legendDot(color: Color(red: 0.3, green: 0.5, blue: 0.9), label: "Kaspi")
                    }
                }

                GeometryReader { geo in
                    let h = geo.size.height
                    let w = geo.size.width
                    let count = max(entry.data.dailyTotals.count, 1)
                    let spacing: CGFloat = 6
                    let barW = max((w - spacing * CGFloat(count - 1)) / CGFloat(count), 4)

                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(normalizedBars.enumerated()), id: \.offset) { i, val in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.04, green: 0.52, blue: 1),
                                                Color(red: 0.08, green: 0.45, blue: 0.95)
                                            ],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(width: barW, height: max(4, h * 0.7 * val))
                                Text(dayLabels.indices.contains(i) ? dayLabels[i] : "")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 70)

                Text("Динамика за 7 дней")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(widgetGradient)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Widget Entry View

struct AutoCoreAccountingWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            DailyExpenseWidgetView(entry: entry)
        case .systemMedium, .systemLarge, .systemExtraLarge:
            LargeWidgetView(entry: entry)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
