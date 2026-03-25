//
//  IOSSoldTabView.swift
//  AutoCore
//
//  Экран «Проданные» для iPhone. Только iOS, данные из AppViewModel (БД).
//

import SwiftUI

#if os(iOS)

struct IOSSoldTabView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var appState: AppState
    
    @State private var selectedMotor: Motor?
    
    private var soldMotors: [Motor] {
        appViewModel.soldMotors
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(soldMotors) { motor in
                    IOSSoldMotorRow(motor: motor, salePrice: appViewModel.soldMotorPrices[motor.id]) {
                        selectedMotor = motor
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: Binding(
                    get: { appViewModel.soldSearchText },
                    set: { appViewModel.setSoldSearchText($0) }
                ),
                prompt: "Поиск проданных"
            )
            .refreshable {
                appViewModel.refreshSoldMotors()
            }
            .navigationTitle("Проданные")
            .onAppear {
                appViewModel.setSelectedSection(.sold)
                appViewModel.refreshSoldMotors()
            }
            .sheet(item: $selectedMotor) { motor in
                IOSMotorDetailSheet(
                    motor: motor,
                    appViewModel: appViewModel,
                    currentUser: appState.authViewModel?.currentUser,
                    onDismiss: { selectedMotor = nil }
                )
            }
        }
    }
}

private struct IOSSoldMotorRow: View {
    let motor: Motor
    let salePrice: Decimal?
    let onTap: () -> Void
    
    private let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(motor.serialCode)
                        .font(.headline)
                    Spacer()
                    if let price = salePrice {
                        Text(priceFormatter.string(from: price as NSDecimalNumber) ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(motor.configuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#endif
