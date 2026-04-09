//
//  FirestoreCompanyMembershipService.swift
//  AutoCore
//
//  Прямой доступ к Firestore (без Cloud Functions). Работает на плане Spark.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class FirestoreCompanyMembershipService: CompanyMembershipService {
    private let db = Firestore.firestore()
    private let inviteService: InviteService
    private let functions = Functions.functions()
    
    init(inviteService: InviteService) {
        self.inviteService = inviteService
    }
    
    func joinCompany(with inviteCode: String, userId: String) async throws {
        let code = normalizeInviteCode(inviteCode)
        guard !code.isEmpty else {
            throw AuthError.unknown("Укажите код приглашения")
        }

        // IMPORTANT:
        // Ранее здесь был прямой update в invites/{id}, который часто падал по rules.
        // Теперь всегда используем Cloud Function, чтобы join работал стабильно.
        do {
            let result = try await functions.httpsCallable("joinCompanyWithInvite").call(["inviteCode": code])
            guard let data = result.data as? [String: Any],
                  (data["success"] as? Bool) == true else {
                throw AuthError.unknown("Не удалось присоединиться к компании")
            }
        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain {
                if let details = error.userInfo[FunctionsErrorDetailsKey] as? String, !details.isEmpty {
                    throw AuthError.unknown(details)
                }
                if let msg = error.userInfo["message"] as? String, !msg.isEmpty {
                    throw AuthError.unknown(msg)
                }
            }
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    private func normalizeInviteCode(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let mapping: [Character: Character] = [
            "А": "A", "В": "B", "С": "C", "Е": "E", "Н": "H", "К": "K", "М": "M", "О": "O",
            "Р": "P", "Т": "T", "У": "Y", "Х": "X", "а": "A", "в": "B", "с": "C", "е": "E",
            "н": "H", "к": "K", "м": "M", "о": "O", "р": "P", "т": "T", "у": "Y", "х": "X"
        ]
        return String(trimmed.map { mapping[$0] ?? $0 })
    }
}

