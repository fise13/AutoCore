//
//  FirestoreCompanyMembershipService.swift
//  AutoCore
//
//  Прямой доступ к Firestore (без Cloud Functions). Работает на плане Spark.
//

import Foundation
import FirebaseFirestore

final class FirestoreCompanyMembershipService: CompanyMembershipService {
    private let db = Firestore.firestore()
    private let inviteService: InviteService
    
    init(inviteService: InviteService) {
        self.inviteService = inviteService
    }
    
    func joinCompany(with inviteCode: String, userId: String) async throws {
        let code = normalizeInviteCode(inviteCode)
        guard !code.isEmpty else {
            throw AuthError.unknown("Укажите код приглашения")
        }
        let invite = try await inviteService.validateInviteCode(code)
        
        // Обновляем документ пользователя
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "companyId": invite.companyId,
            "role": invite.role.rawValue
        ])
        try await inviteService.markInviteUsed(invite.id)
        
        // После обновления документа пользователя клиент должен принудительно обновить токен:
        // Auth.auth().currentUser?.getIDTokenResult(true)
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

