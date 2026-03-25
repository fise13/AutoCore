//
//  FirestoreInviteService.swift
//  AutoCore
//

import Foundation
import FirebaseFirestore

func generateInviteCode(length: Int = 6) -> String {
    let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    return String((0..<length).compactMap { _ in characters.randomElement() })
}

final class FirestoreInviteService: InviteService {
    private let db = Firestore.firestore()
    
    func createInvite(companyId: String, role: UserRole, createdBy: String, ttl: TimeInterval) async throws -> InviteDocument {
        let code = generateInviteCode()
        let expiresAtDate = Date().addingTimeInterval(ttl)
        let data: [String: Any] = [
            "code": code,
            "companyId": companyId,
            "role": role.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: expiresAtDate),
            "createdBy": createdBy,
            "used": false
        ]
        let ref = try await db.collection("invites").addDocument(data: data)
        return InviteDocument(
            id: ref.documentID,
            code: code,
            companyId: companyId,
            role: role,
            createdAt: nil,
            expiresAt: expiresAtDate,
            createdBy: createdBy,
            used: false
        )
    }
    
    func validateInviteCode(_ code: String) async throws -> InviteDocument {
        let snapshot = try await db.collection("invites")
            .whereField("code", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else {
            throw AuthError.unknown("Код приглашения не найден")
        }
        let data = doc.data()
        let companyId = data["companyId"] as? String ?? ""
        let roleRaw = data["role"] as? String ?? UserRole.viewer.rawValue
        let role = UserRole(rawValue: roleRaw) ?? .viewer
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        guard let expiresTs = data["expiresAt"] as? Timestamp else {
            throw AuthError.unknown("Некорректные данные приглашения")
        }
        let expiresAt = expiresTs.dateValue()
        let createdBy = data["createdBy"] as? String ?? ""
        let used = data["used"] as? Bool ?? false
        
        let invite = InviteDocument(
            id: doc.documentID,
            code: code,
            companyId: companyId,
            role: role,
            createdAt: createdAt,
            expiresAt: expiresAt,
            createdBy: createdBy,
            used: used
        )
        
        guard !invite.used else { throw AuthError.unknown("Код приглашения уже использован") }
        guard invite.expiresAt > Date() else { throw AuthError.unknown("Срок действия кода истёк") }
        
        return invite
    }
    
    func markInviteUsed(_ inviteId: String) async throws {
        try await db.collection("invites").document(inviteId).updateData(["used": true])
    }
}

