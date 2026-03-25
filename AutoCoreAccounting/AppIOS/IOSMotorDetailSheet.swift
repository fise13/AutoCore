//
//  IOSMotorDetailSheet.swift
//  AutoCore
//
//  Детали мотора на iPhone + кнопки Продать/Вернуть.
//

import SwiftUI

#if os(iOS)

struct IOSMotorDetailSheet: View {
    let motor: Motor
    @ObservedObject var appViewModel: AppViewModel
    let currentUser: UserEntity?
    let onDismiss: () -> Void
    
    @State private var showSellSheet = false
    @State private var showRefundSheet = false
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Двигатель") {
                    LabeledContent("Номер", value: motor.serialCode)
                    LabeledContent("Бренд", value: motor.brandName)
                    LabeledContent("Код двигателя", value: motor.engineCode)
                    LabeledContent("Комплектация", value: motor.configuration)
                    LabeledContent("Коробка", value: motor.transmission)
                    LabeledContent("Кол-во", value: "\(motor.quantity)")
                }
                Section("Даты") {
                    LabeledContent("Приход", value: dateFormatter.string(from: motor.arrivalDate))
                    if let sold = motor.soldDate {
                        LabeledContent("Продан", value: dateFormatter.string(from: sold))
                    }
                }
                if !motor.notes.isEmpty {
                    Section("Заметки") {
                        Text(motor.notes)
                    }
                }
                Section {
                    if motor.availability == .available {
                        Button {
                            showSellSheet = true
                        } label: {
                            Label("Продать", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button {
                            showRefundSheet = true
                        } label: {
                            Label("Вернуть", systemImage: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle(motor.serialCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSellSheet) {
                if let user = currentUser {
                    SellMotorSheetView(
                        motor: motor,
                        onConfirm: { amount, paymentMethod, cashReceived, account, comment in
                            appViewModel.sellMotorWithFinancialOperation(
                                motorID: motor.id,
                                saleAmount: amount,
                                paymentMethod: paymentMethod,
                                cashReceived: cashReceived,
                                account: account,
                                comment: comment,
                                currentUser: user.email,
                                companyId: user.companyId
                            )
                            showSellSheet = false
                            onDismiss()
                            dismiss()
                        },
                        onCancel: { showSellSheet = false }
                    )
                }
            }
            .sheet(isPresented: $showRefundSheet) {
                if let user = currentUser {
                    RefundMotorSheetView(
                        motor: motor,
                        onConfirm: { amount, paymentMethod, cashReceived, account, comment in
                            appViewModel.refundMotorWithFinancialOperation(
                                motorID: motor.id,
                                refundAmount: amount,
                                paymentMethod: paymentMethod,
                                cashReceived: cashReceived,
                                account: account,
                                comment: comment,
                                currentUser: user.email,
                                companyId: user.companyId
                            )
                            showRefundSheet = false
                            onDismiss()
                            dismiss()
                        },
                        onCancel: { showRefundSheet = false }
                    )
                }
            }
        }
    }
}

#endif
