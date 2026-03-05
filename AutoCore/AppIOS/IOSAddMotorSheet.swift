//
//  IOSAddMotorSheet.swift
//  AutoCore
//
//  Добавление мотора на iPhone. Использует общий AddMotorView и AppViewModel.
//

import SwiftUI

#if os(iOS)

struct IOSAddMotorSheet: View {
    @ObservedObject var appViewModel: AppViewModel
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            AddMotorView(
                brands: appViewModel.brands,
                engines: appViewModel.engines,
                onSave: { brandName, engineCode, serialCode, configuration, notes, quantity, transmission, arrivalDate, soldDate in
                    appViewModel.addManualMotor(
                        brandName: brandName,
                        engineCode: engineCode,
                        serialCode: serialCode,
                        configuration: configuration,
                        notes: notes,
                        quantity: quantity,
                        transmission: transmission,
                        arrivalDate: arrivalDate,
                        soldDate: soldDate
                    )
                    onDismiss()
                    dismiss()
                }
            )
            .navigationTitle("Новый мотор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

#endif
