//
//  IOSMotorsTabView.swift
//  AutoCore
//
//  Экран «Моторы» для iPhone. Только iOS, использует AppViewModel (БД).
//

import SwiftUI

#if os(iOS)

struct IOSMotorsTabView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var appState: AppState
    
    @State private var selectedMotor: Motor?
    @State private var motorToSell: Motor?
    @State private var showAddMotor = false
    
    private var motors: [Motor] {
        appViewModel.filteredMotors
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(motors) { motor in
                    IOSMotorRow(motor: motor) {
                        selectedMotor = motor
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if motor.availability == .available {
                            Button(role: .none) {
                                motorToSell = motor
                            } label: {
                                Label("Продать", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: Binding(
                    get: { appViewModel.searchText },
                    set: { appViewModel.setSearchText($0) }
                ),
                prompt: "Поиск по номеру, конфигурации..."
            )
            .refreshable {
                appViewModel.refreshAll()
            }
            .navigationTitle("Моторы")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddMotor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .onAppear {
                appViewModel.setSelectedSection(.all)
                appViewModel.refreshAll()
            }
            .sheet(item: $selectedMotor) { motor in
                IOSMotorDetailSheet(
                    motor: motor,
                    appViewModel: appViewModel,
                    currentUser: appState.authViewModel?.currentUser,
                    onDismiss: { selectedMotor = nil }
                )
            }
            .sheet(item: $motorToSell) { motor in
                if let user = appState.authViewModel?.currentUser {
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
                            motorToSell = nil
                            appViewModel.refreshAll()
                        },
                        onCancel: { motorToSell = nil }
                    )
                }
            }
            .sheet(isPresented: $showAddMotor) {
                IOSAddMotorSheet(appViewModel: appViewModel, onDismiss: {
                    showAddMotor = false
                    appViewModel.refreshAll()
                })
            }
        }
    }
}

private struct IOSMotorRow: View {
    let motor: Motor
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(motor.serialCode)
                        .font(.headline)
                    Spacer()
                    if motor.soldDate != nil {
                        Text("Продан")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(motor.configuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !motor.notes.isEmpty {
                    Text(motor.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#endif
