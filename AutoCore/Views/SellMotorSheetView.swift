import SwiftUI

struct SellMotorSheetView: View {
    let motor: Motor
    let onConfirm: (Decimal, FinancialOperationEntity.PaymentMethod, Decimal?, FinancialOperationEntity.Account, String) -> Void
    let onCancel: () -> Void
    
    @State private var saleAmount: String = ""
    @State private var paymentMethod: FinancialOperationEntity.PaymentMethod = .cash
    @State private var cashReceived: String = ""
    @State private var account: FinancialOperationEntity.Account = .cashbox
    @State private var comment: String = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case saleAmount
        case cashReceived
        case comment
    }
    
    private var calculatedChange: Decimal {
        guard let amount = parseDecimal(saleAmount),
              let received = parseDecimal(cashReceived),
              paymentMethod == .cash || paymentMethod == .mixed else {
            return 0
        }
        return max(0, received - amount)
    }
    
    private var isValid: Bool {
        guard let amount = parseDecimal(saleAmount), amount > 0 else {
            return false
        }
        
        if paymentMethod == .cash || paymentMethod == .mixed {
            guard let received = parseDecimal(cashReceived), received >= amount else {
                return false
            }
        }
        
        return true
    }
    
    private var validationMessage: String? {
        guard let amount = parseDecimal(saleAmount), amount > 0 else {
            return nil
        }
        
        if paymentMethod == .cash || paymentMethod == .mixed {
            if let received = parseDecimal(cashReceived), received < amount {
                return "Недостаточно средств"
            }
        }
        
        return nil
    }
    
    private func parseDecimal(_ string: String) -> Decimal? {
        let cleaned = string.replacingOccurrences(of: ",", with: ".")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.number(from: cleaned)?.decimalValue
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. КОНТЕКСТ (READ-ONLY, ВТОРИЧНЫЙ)
                contextSection
                
                Divider()
                
                // 2. ФИНАНСЫ (ГЛАВНЫЙ ФОКУС)
                ScrollView {
                    VStack(spacing: 24) {
                        financesSection
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // 3. ДИНАМИЧЕСКАЯ ЛОГИКА ПОЛЕЙ
                        if paymentMethod == .cash || paymentMethod == .mixed {
                            cashPaymentFields
                        } else {
                            transferPaymentFields
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // 4. СЧЁТ
                        accountSection
                        
                        // 5. КОММЕНТАРИЙ
                        commentSection
                        
                        // 6. ВАЛИДАЦИЯ (INLINE)
                        if let message = validationMessage {
                            validationMessageView(message)
                        }
                    }
                    .padding(24)
                }
                
                Divider()
                
                // 7. КНОПКИ ДЕЙСТВИЯ
                buttonsSection
            }
            .frame(minWidth: 520, minHeight: 500)
            .navigationTitle("Продажа мотора")
        }
    }
    
    // MARK: - Context Section
    
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(motor.serialCode)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            
            HStack(spacing: 8) {
                Text(motor.brandName)
                    .font(.system(size: 13))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(motor.engineCode.uppercased())
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Finances Section
    
    private var financesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Цена продажи")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("Введите сумму продажи", text: $saleAmount)
                    .textFieldStyle(.plain)
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .focused($focusedField, equals: .saleAmount)
                    .onChange(of: saleAmount) { _, newValue in
                        // Автоматически заполняем получено суммой продажи для наличных
                        if paymentMethod == .cash || paymentMethod == .mixed {
                            if cashReceived.isEmpty, let amount = parseDecimal(newValue) {
                                cashReceived = String(describing: amount)
                            }
                        }
                    }
                
                Text("₸")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(focusedField == .saleAmount ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            
            // Способ оплаты
            Picker("Способ оплаты", selection: $paymentMethod) {
                Text("Наличные").tag(FinancialOperationEntity.PaymentMethod.cash)
                Text("Перевод").tag(FinancialOperationEntity.PaymentMethod.transfer)
                Text("Смешанная").tag(FinancialOperationEntity.PaymentMethod.mixed)
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Cash Payment Fields
    
    private var cashPaymentFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Получено
            VStack(alignment: .leading, spacing: 8) {
                Text("Получено")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Введите полученную сумму", text: $cashReceived)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .regular))
                        .focused($focusedField, equals: .cashReceived)
                    
                    Text("₸")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            
            // Сдача (read-only)
            if let amount = parseDecimal(saleAmount),
               let received = parseDecimal(cashReceived),
               received >= amount {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Сдача")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(formatCurrency(calculatedChange))
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(.secondary)
                        
                        Text("₸")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Transfer Payment Fields
    
    private var transferPaymentFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Комментарий / номер операции")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("Например: номер перевода, комментарий...", text: $comment, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focusedField, equals: .comment)
                .lineLimit(2...4)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Счёт", selection: $account) {
                Text("Касса").tag(FinancialOperationEntity.Account.cashbox)
                Text("Каспи").tag(FinancialOperationEntity.Account.kaspi)
            }
            .pickerStyle(.segmented)
            
            Text("Средства будут зачислены в: \(account == .cashbox ? "Касса" : "Каспи")")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Comment Section
    
    private var commentSection: some View {
        Group {
            if paymentMethod == .cash || paymentMethod == .mixed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Комментарий")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("Комментарий (необязательно)", text: $comment, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($focusedField, equals: .comment)
                        .lineLimit(2...4)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Validation Message
    
    private func validationMessageView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 12))
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Buttons Section
    
    private var buttonsSection: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button("Отмена") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Подтвердить продажу") {
                confirmSale()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
            .keyboardShortcut(.defaultAction)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Операция будет записана в бухгалтерию")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Actions
    
    private func confirmSale() {
        guard let amount = parseDecimal(saleAmount), amount > 0 else {
            return
        }
        
        var cashReceivedDecimal: Decimal?
        if paymentMethod == .cash || paymentMethod == .mixed {
            if let received = parseDecimal(cashReceived), received >= amount {
                cashReceivedDecimal = received
            } else {
                return
            }
        }
        
        onConfirm(amount, paymentMethod, cashReceivedDecimal, account, comment)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
