import SwiftUI
import Combine

/// Состояние выделенной ячейки (БЕЗ редактирования)
struct SelectedCell: Equatable {
    let motorID: Int64
    let field: EditableCellState.EditableField
}

/// Состояние редактируемой ячейки
struct EditingCell: Equatable {
    let motorID: Int64
    let field: EditableCellState.EditableField
    let initialValue: String
}

@MainActor
final class InlineEditViewModel: ObservableObject {
    // РАЗДЕЛЬНЫЕ состояния: выделение и редактирование
    @Published var selectedCell: SelectedCell?
    @Published var editingCell: EditingCell?
    
    var onCellSave: ((Int64, EditableCellState.EditableField, String) -> Void)?
    
    /// Начать редактирование ячейки (вызывается при двойном клике или Enter)
    func startEditing(motorID: Int64, field: EditableCellState.EditableField, currentValue: String) {
        editingCell = EditingCell(
            motorID: motorID,
            field: field,
            initialValue: currentValue
        )
        // Выделение сохраняется при входе в режим редактирования
    }
    
    /// Выделить ячейку (один клик)
    func selectCell(motorID: Int64, field: EditableCellState.EditableField) {
        selectedCell = SelectedCell(motorID: motorID, field: field)
        // НЕ трогаем editingCell - это отдельное состояние
    }
    
    /// Сохранить изменения и выйти из режима редактирования
    func saveCell(motorID: Int64, field: EditableCellState.EditableField, value: String) {
        onCellSave?(motorID, field, value)
        editingCell = nil
        // Выделение остается
    }
    
    /// Отменить редактирование
    func cancelEditing() {
        editingCell = nil
        // Выделение остается
    }
    
    /// Начать редактирование выделенной ячейки (Enter)
    func startEditingSelectedCell(motors: [Motor]) {
        guard let selected = selectedCell else { return }
        
        let currentValue = getCurrentValue(
            motorID: selected.motorID,
            field: selected.field,
            motors: motors
        )
        
        startEditing(
            motorID: selected.motorID,
            field: selected.field,
            currentValue: currentValue
        )
    }
    
    /// Переход к следующей/предыдущей ячейке при редактировании (Tab/Shift+Tab)
    func moveToNextCell(currentMotorID: Int64, currentField: EditableCellState.EditableField, motors: [Motor], forward: Bool = true) {
        let fields = EditableCellState.EditableField.allCases
        guard let currentIndex = fields.firstIndex(of: currentField) else { return }
        
        let nextIndex = forward ? fields.index(after: currentIndex) : fields.index(before: currentIndex)
        
        if nextIndex < fields.endIndex && nextIndex >= fields.startIndex {
            // Следующее поле в той же строке
            let nextField = fields[nextIndex]
            let nextValue = getCurrentValue(motorID: currentMotorID, field: nextField, motors: motors)
            startEditing(motorID: currentMotorID, field: nextField, currentValue: nextValue)
            // Обновляем выделение
            selectCell(motorID: currentMotorID, field: nextField)
        } else {
            // Переход на следующую/предыдущую строку
            guard let currentMotorIndex = motors.firstIndex(where: { $0.id == currentMotorID }) else { return }
            
            let nextMotorIndex = forward ? motors.index(after: currentMotorIndex) : motors.index(before: currentMotorIndex)
            
            if nextMotorIndex < motors.endIndex && nextMotorIndex >= motors.startIndex {
                let nextMotor = motors[nextMotorIndex]
                let firstField = forward ? fields.first! : fields.last!
                let nextValue = getCurrentValue(motorID: nextMotor.id, field: firstField, motors: motors)
                startEditing(motorID: nextMotor.id, field: firstField, currentValue: nextValue)
                // Обновляем выделение
                selectCell(motorID: nextMotor.id, field: firstField)
            }
        }
    }
    
    private func getCurrentValue(motorID: Int64, field: EditableCellState.EditableField, motors: [Motor]) -> String {
        guard let motor = motors.first(where: { $0.id == motorID }) else { return "" }
        
        switch field {
        case .serialCode:
            return motor.serialCode
        case .configuration:
            return motor.configuration
        case .notes:
            return motor.notes
        case .quantity:
            return "\(motor.quantity)"
        case .transmission:
            return motor.transmission
        case .arrivalDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: motor.arrivalDate)
        case .soldDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let soldDate = motor.soldDate {
                return formatter.string(from: soldDate)
            } else {
                return ""
            }
        }
    }
}
