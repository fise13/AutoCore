//
//  FirestoreFunctionsCompanyMembershipService.swift
//  AutoCore
//
//  Использует Cloud Function joinCompanyWithInvite — устраняет "Missing or insufficient permissions".
//  Пользователь, присоединяющийся по коду, не может обновлять invites (нужны права owner/admin).
//

import Foundation
import FirebaseFunctions

final class FirestoreFunctionsCompanyMembershipService: CompanyMembershipService {
    private let functions = Functions.functions()

    func joinCompany(with inviteCode: String, userId: String) async throws {
        let code = normalizeInviteCode(inviteCode)
        guard !code.isEmpty else {
            throw AuthError.unknown("Укажите код приглашения")
        }

        do {
            let result = try await functions.httpsCallable("joinCompanyWithInvite").call(["inviteCode": code])
            guard let data = result.data as? [String: Any],
                  (data["success"] as? Bool) == true else {
                throw AuthError.unknown("Не удалось присоединиться к компании")
            }
        } catch let error as NSError {
            let msg = extractFunctionsErrorMessage(error)
            throw AuthError.unknown(msg)
        }

        // syncUserClaims обновит claims при изменении users/{userId}
        // Клиент должен вызвать refreshCurrentUser() для обновления токена
    }

    /// Нормализует код приглашения: trim, uppercase, заменяет кириллицу на латиницу.
    /// Решает проблему, когда пользователь копирует код и получает похожие символы (А→A, С→C и т.д.).
    private func normalizeInviteCode(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let mapping: [Character: Character] = [
            "А": "A", "В": "B", "С": "C", "Е": "E", "Н": "H", "К": "K", "М": "M", "О": "O",
            "Р": "P", "Т": "T", "У": "Y", "Х": "X", "а": "A", "в": "B", "с": "C", "е": "E",
            "н": "H", "к": "K", "м": "M", "о": "O", "р": "P", "т": "T", "у": "Y", "х": "X"
        ]
        return String(trimmed.map { mapping[$0] ?? $0 })
    }

    private func extractFunctionsErrorMessage(_ error: NSError) -> String {
        if error.domain == FunctionsErrorDomain {
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? String, !details.isEmpty {
                return details
            }
            if let msg = error.userInfo["message"] as? String, !msg.isEmpty {
                return msg
            }
        }
        return error.localizedDescription
    }
}
