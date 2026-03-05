import Foundation

/// Период дашборда для KPI и графиков
enum DashboardPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .day: return "День"
        case .week: return "Неделя"
        case .month: return "Месяц"
        case .year: return "Год"
        }
    }
    
    /// Количество точек для графика динамики
    var chartDataPoints: Int {
        switch self {
        case .day: return 7
        case .week: return 12
        case .month: return 12
        case .year: return 12
        }
    }
}

/// KPI за период (доходы, расходы, чистая прибыль, количество операций)
struct DashboardKPIs {
    var income: Decimal
    var expenses: Decimal
    var netProfit: Decimal
    var operationCount: Int
    var incomeChangePercent: Double?
    var expensesChangePercent: Double?
    var netProfitChangePercent: Double?
    var operationCountChangePercent: Double?
}

/// Точка для графика Cash Flow по времени
struct CashFlowDataPoint: Identifiable {
    let id: String
    let date: Date
    let income: Decimal
    let expenses: Decimal
    let net: Decimal
}

/// Категория расходов с долей
struct ExpenseCategoryItem: Identifiable {
    let id: String
    let category: String
    let amount: Decimal
    let percent: Double
}
