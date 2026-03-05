import Foundation

/// Domain Entity: Financial Operation
/// Представляет финансовую операцию (продажа, возврат, расход)
struct FinancialOperationEntity {
    let id: Int64
    let type: OperationType
    let amount: Decimal
    let paymentMethod: PaymentMethod
    let cashReceived: Decimal?
    let changeGiven: Decimal?
    let account: Account
    let relatedMotorID: Int64?
    let createdAt: Date
    let createdByUser: String
    let comment: String
    let source: String  // Откуда пришло (например: "Продажа мотора", "Возврат", "Расход")
    let details: String  // Детали операции (например: "Мотор #123", "Оплата аренды")
    let category: String?  // Категория расхода (свободный текст, пользовательский)
    let description: String  // Человекочитаемое описание операции (обязательно для расходов)
    
    /// Тип операции
    enum OperationType: String, Codable {
        case sale = "sale"
        /// Прямой приход денег (внесение средств без привязки к мотору)
        case income = "income"
        case refund = "refund"
        case expense = "expense"
        case transfer = "transfer"
    }
    
    /// Способ оплаты
    enum PaymentMethod: String, Codable {
        case cash = "cash"
        case transfer = "transfer"
        case mixed = "mixed"
    }
    
    /// Счёт (касса или Каспи)
    enum Account: String, Codable {
        case cashbox = "cashbox"
        case kaspi = "kaspi"
    }
    
    /// Domain Rule: для cash операций cashReceived обязателен (кроме расходов)
    func validate() throws {
        // Для расходов не требуется cashReceived - это списание денег, а не получение
        if type != .expense && (paymentMethod == .cash || paymentMethod == .mixed) {
            guard let received = cashReceived, received >= 0 else {
                throw DomainError.validationError(message: "Для наличной оплаты необходимо указать полученную сумму")
            }
            
            // Проверка сдачи
            if let change = changeGiven, change < 0 {
                throw DomainError.validationError(message: "Сдача не может быть отрицательной")
            }
            
            // Проверка логики сдачи
            if received < amount {
                throw DomainError.validationError(message: "Полученная сумма не может быть меньше суммы операции")
            }
            
            if let change = changeGiven {
                let calculatedChange = received - amount
                if abs(calculatedChange - change) > Decimal(0.01) {
                    throw DomainError.validationError(message: "Неверный расчёт сдачи")
                }
            }
        }
        
        guard amount > 0 else {
            throw DomainError.validationError(message: "Сумма операции должна быть больше нуля")
        }
        
        // Для расходов описание обязательно
        if type == .expense && description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DomainError.validationError(message: "Для расхода необходимо указать описание")
        }
    }
    
    /// Вычисляет сдачу автоматически
    static func calculateChange(cashReceived: Decimal, amount: Decimal) -> Decimal {
        return max(0, cashReceived - amount)
    }
}
