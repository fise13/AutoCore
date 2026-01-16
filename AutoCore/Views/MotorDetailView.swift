import SwiftUI

struct MotorDetailView: View {
    let motor: Motor?
    let isSold: Bool
    let onSave: (Int64, String, String, Int, String, Date, Date?) -> Void
    let onToggleSold: (Int64, Bool) -> Void

    @State private var configurationText = ""
    @State private var notesText = ""
    @State private var quantityText = "1"
    @State private var transmissionText = ""
    @State private var arrivalDate = Date()
    @State private var soldState = false
    @State private var soldDate = Date()

    var body: some View {
        if let motor {
            Form {
                Section("Основное") {
                    LabeledContent("Серийный номер", value: motor.serialCode)
                    LabeledContent("Бренд", value: motor.brandName)
                    LabeledContent("Двигатель", value: motor.engineCode.uppercased())
                    LabeledContent("Создан", value: formattedDate(motor.createdAt))
                }

                Section("Комплектация") {
                    TextField("Комплектация", text: $configurationText)
                        .disabled(isSold)
                    TextField("Особые отметки", text: $notesText)
                    TextField("Кол-во", text: $quantityText)
                        .disabled(isSold)
                    TextField("Коробка", text: $transmissionText)
                        .disabled(isSold)
                }

                Section("Даты") {
                    DatePicker("Дата прихода", selection: $arrivalDate, displayedComponents: .date)
                        .disabled(isSold)
                    HStack {
                        Text(soldState ? "Продан" : "В наличии")
                        Spacer()
                        if !isSold {
                            Button(soldState ? "Вернуть в наличие" : "Продать") {
                                onToggleSold(motor.id, !soldState)
                            }
                        } else {
                            Button("Вернуть в наличие") {
                                onToggleSold(motor.id, false)
                            }
                        }
                    }
                    if soldState {
                        Text("Дата продажи: \(formattedDate(soldDate))")
                            .foregroundStyle(.secondary)
                    }
                }

                if !isSold {
                    Section {
                        Button("Сохранить") {
                            let quantity = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                            onSave(
                                motor.id,
                                configurationText.trimmingCharacters(in: .whitespacesAndNewlines),
                                notesText.trimmingCharacters(in: .whitespacesAndNewlines),
                                max(quantity, 1),
                                transmissionText.trimmingCharacters(in: .whitespacesAndNewlines),
                                arrivalDate,
                                soldState ? soldDate : nil
                            )
                        }
                    }
                } else {
                    Section {
                        Button("Сохранить отметки") {
                            let quantity = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                            onSave(
                                motor.id,
                                motor.configuration,
                                notesText.trimmingCharacters(in: .whitespacesAndNewlines),
                                motor.quantity,
                                motor.transmission,
                                motor.arrivalDate,
                                motor.soldDate
                            )
                        }
                    }
                }
            }
            .padding()
            .onAppear {
                syncState(with: motor)
            }
            .onChange(of: motor) { _, newValue in
                syncState(with: newValue)
            }
        } else {
            ContentUnavailableView("Выберите мотор", systemImage: "engine.combustion")
        }
    }

    private func syncState(with motor: Motor) {
        configurationText = motor.configuration
        notesText = motor.notes
        quantityText = "\(motor.quantity)"
        transmissionText = motor.transmission
        arrivalDate = motor.arrivalDate
        soldState = motor.soldDate != nil
        soldDate = motor.soldDate ?? Date()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
