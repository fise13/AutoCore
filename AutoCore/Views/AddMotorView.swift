import SwiftUI

struct AddMotorView: View {
    let brands: [Brand]
    let engines: [Engine]
    var onSave: (String, String, String, String, String, Int, String, Date, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBrandID: Int64? = nil
    @State private var selectedEngineID: Int64? = nil
    @State private var customBrand = ""
    @State private var customEngineCode = ""
    @State private var serialCode = ""
    @State private var configuration = ""
    @State private var notes = ""
    @State private var quantity = "1"
    @State private var transmission = ""
    @State private var arrivalDate = Date()
    @State private var isSold = false

    private var availableEngines: [Engine] {
        guard let brandID = selectedBrandID else { return [] }
        return engines.filter { $0.brandID == brandID }
    }
    
    private var selectedBrand: Brand? {
        brands.first { $0.id == selectedBrandID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Новый мотор")
                .font(.title2)

            Form {
                Picker("Бренд", selection: $selectedBrandID) {
                    Text("Выберите бренд").tag(Int64?.none)
                    ForEach(brands) { brand in
                        Text(brand.name).tag(Int64?.some(brand.id))
                    }
                }
                .onChange(of: selectedBrandID) { _, _ in
                    selectedEngineID = nil
                }
                
                if selectedBrandID == nil {
                    TextField("Или введите новый бренд", text: $customBrand)
                }
                
                if selectedBrandID != nil {
                    Picker("Код двигателя", selection: $selectedEngineID) {
                        Text("Выберите двигатель").tag(Int64?.none)
                        ForEach(availableEngines) { engine in
                            Text(engine.code.uppercased()).tag(Int64?.some(engine.id))
                        }
                    }
                }
                
                if selectedEngineID == nil {
                    TextField("Или введите новый код двигателя", text: $customEngineCode)
                }
                
                TextField("Серийный номер", text: $serialCode)
                TextField("Комплектация", text: $configuration)
                TextField("Особые отметки", text: $notes)
                TextField("Кол-во", text: $quantity)
                TextField("Коробка", text: $transmission)
                DatePicker("Дата прихода", selection: $arrivalDate, displayedComponents: .date)
                Toggle("Продан", isOn: $isSold)
            }
            .frame(maxWidth: 520)

            HStack {
                Button("Отмена") {
                    dismiss()
                }
                Spacer()
                Button("Сохранить") {
                    let brandName = selectedBrand?.name ?? customBrand.trimmingCharacters(in: .whitespacesAndNewlines)
                    let engineCodeValue = selectedEngineID.flatMap { id in
                        engines.first { $0.id == id }?.code
                    } ?? customEngineCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let qty = Int(quantity.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                    onSave(
                        brandName,
                        engineCodeValue,
                        serialCode.trimmingCharacters(in: .whitespacesAndNewlines),
                        configuration.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        max(qty, 1),
                        transmission.trimmingCharacters(in: .whitespacesAndNewlines),
                        arrivalDate,
                        isSold ? Date() : nil
                    )
                }
                .disabled(
                    (selectedBrandID == nil && customBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                    (selectedEngineID == nil && customEngineCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                    serialCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding()
        .frame(minWidth: 560)
    }
}
