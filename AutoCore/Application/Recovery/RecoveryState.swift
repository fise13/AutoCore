import Foundation
import Combine

/// Recovery Mode State
/// Управляет состоянием режима восстановления при ошибках БД
@MainActor
final class RecoveryState: ObservableObject {
    /// Текущий режим восстановления
    @Published private(set) var isRecoveryMode: Bool = false
    
    /// Сообщение об ошибке, вызвавшей режим восстановления
    @Published private(set) var recoveryMessage: String?
    
    /// Причина перехода в режим восстановления
    enum RecoveryReason {
        case databaseOpenFailed(String)
        case databaseValidationFailed(String)
        case migrationFailed(String)
        
        var message: String {
            switch self {
            case .databaseOpenFailed(let msg):
                return "Не удалось открыть базу данных: \(msg)"
            case .databaseValidationFailed(let msg):
                return "Ошибка валидации базы данных: \(msg)"
            case .migrationFailed(let msg):
                return "Ошибка миграции базы данных: \(msg)"
            }
        }
    }
    
    /// Включить режим восстановления
    func enable(reason: RecoveryReason) {
        isRecoveryMode = true
        recoveryMessage = reason.message
    }
    
    /// Выключить режим восстановления
    func disable() {
        isRecoveryMode = false
        recoveryMessage = nil
    }
    
    /// Проверка, разрешена ли мутирующая операция
    func assertNotInRecoveryMode() throws {
        guard !isRecoveryMode else {
            throw AppError.databaseError(
                message: "Операция заблокирована в режиме восстановления. \(recoveryMessage ?? "")"
            )
        }
    }
}
