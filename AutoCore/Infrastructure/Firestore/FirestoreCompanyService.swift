//
//  FirestoreCompanyService.swift
//  AutoCore
//

import Foundation
import FirebaseFirestore

final class FirestoreCompanyService: CompanyService {
    private let db = Firestore.firestore()
    
    func createCompany(name: String, ownerId: String) async throws -> CompanyDocument {
        let data: [String: Any] = [
            "name": name,
            "ownerId": ownerId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        let ref = try await db.collection("companies").addDocument(data: data)
        return CompanyDocument(id: ref.documentID, name: name, ownerId: ownerId, createdAt: nil)
    }
    
    /// Создаёт документ companies/default если его нет, привязывает пользователя к компании "default" (чтобы Mac и iOS видели одни данные).
    func ensureDefaultCompany(ownerId: String) async throws {
        let defaultId = "default"
        let ref = db.collection("companies").document(defaultId)
        let snapshot = try await ref.getDocument()
        if !snapshot.exists {
            try await ref.setData([
                "name": "Моя бухгалтерия",
                "ownerId": ownerId,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
        try await assignUserToCompany(userId: ownerId, companyId: defaultId, role: .owner)
    }
    
    func fetchCompany(companyId: String) async throws -> CompanyDocument? {
        let snapshot = try await db.collection("companies").document(companyId).getDocument()
        guard let data = snapshot.data() else { return nil }
        
        let name = data["name"] as? String ?? ""
        let ownerId = data["ownerId"] as? String ?? ""
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        return CompanyDocument(id: snapshot.documentID, name: name, ownerId: ownerId, createdAt: createdAt)
    }
    
    func assignUserToCompany(userId: String, companyId: String, role: UserRole) async throws {
        let data: [String: Any] = [
            "companyId": companyId,
            "role": role.rawValue
        ]
        do {
            try await db.collection("users").document(userId).updateData(data)
        } catch {
            // Документ может не существовать (редкий кейс) — создаём с merge
            try await db.collection("users").document(userId).setData(data, merge: true)
        }
    }
}

