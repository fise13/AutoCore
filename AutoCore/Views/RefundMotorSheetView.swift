import SwiftUI

struct RefundMotorSheetView: View {
    let motor: Motor
    let onConfirm: (Decimal, FinancialOperationEntity.PaymentMethod, Decimal?, FinancialOperationEntity.Account, String) -> Void
    let onCancel: () -> Void
    
    @State private var refundAmount: String = ""
    @State private var paymentMethod: FinancialOperationEntity.PaymentMethod = .cash
    @State private var cashReceived: String = ""
    @State private var account: FinancialOperationEntity.Account = .cashbox
    @State private var comment: String = ""
    @State private var errorMessage: String?
    
    private var calculatedChange: Decimal {
        guard let amount = parseDecimal(refundAmount),
              let received = parseDecimal(cashReceived),
              paymentMethod == .cash || paymentMethod == .mixed else {
            return 0
        }
        return max(0, received - amount)
    }
    
    private var isValid: Bool {
        guard let amount = parseDecimal(refundAmount), amount > 0 else {
            return false
        }
        
        if paymentMethod == .cash || paymentMethod == .mixed {
            guard let received = parseDecimal(cashReceived), received >= amount else {
                return false
            }
        }
        
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Мотор") {
                    LabeledContent("Серийный номер", value: motor.serialCode)
                    LabeledContent("Бренд", value: motor.brandName)
                    LabeledContent("Двигатель", value: motor.engineCode.uppercased())
                }
                
                Section("Финансы") {
                    TextField("Сумма возврата", text: $refundAmount)
                    
                    Picker("Способ оплаты", selection: $paymentMethod) {
                        Text("Наличные").tag(FinancialOperationEntity.PaymentMethod.cash)
                        Text("Перевод").tag(FinancialOperationEntity.PaymentMethod.transfer)
                        Text("Смешанная").tag(FinancialOperationEntity.PaymentMethod.mixed)
                    }
                    
                    Picker("Счёт", selection: $account) {
                        Text("Касса").tag(FinancialOperationEntity.Account.cashbox)
                        Text("Каспи").tag(FinancialOperationEntity.Account.kaspi)
                    }
                    
                    if paymentMethod == .cash || paymentMethod == .mixed {
                        TextField("Выдано", text: $cashReceived)
                            .onChange(of: refundAmount) { _, _ in
                                // Автоматически заполняем выдано суммой возврата
                                if cashReceived.isEmpty, let amount = parseDecimal(refundAmount) {
                                    cashReceived = String(describing: amount)
                                }
                            }
                        
                        if let amount = parseDecimal(refundAmount),
                           let received = parseDecimal(cashReceived),
                           received >= amount {
                            LabeledContent("Сдача", value: formatCurrency(calculatedChange))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Комментарий") {
                    TextField("Комментарий (необязательно)", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Возврат мотора")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Подтвердить") {
                        confirmRefund()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func confirmRefund() {
        guard let amount = parseDecimal(refundAmount), amount > 0 else {
            errorMessage = "Введите корректную сумму возврата"
            return
        }
        
        var cashReceivedDecimal: Decimal?
        if paymentMethod == .cash || paymentMethod == .mixed {
            guard let received = parseDecimal(cashReceived), received >= amount else {
                errorMessage = "Выданная сумма должна быть не меньше суммы возврата"
                return
            }
            cashReceivedDecimal = received
        }
        
        errorMessage = nil
        onConfirm(amount, paymentMethod, cashReceivedDecimal, account, comment)
    }
    
    private func parseDecimal(_ string: String) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.number(from: string)?.decimalValue
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.currencySymbol = "₸"
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₸"
    }
}
