//
//  FirestoreCompanyMembersService.swift
//  AutoCore
//

import Foundation
import FirebaseFirestore

final class FirestoreCompanyMembersService: CompanyMembersService {
    private let db = Firestore.firestore()

    func fetchMembers(companyId: String) async throws -> [UserDocument] {
        guard !companyId.isEmpty else { return [] }

        let snapshot = try await db.collection("users")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> UserDocument? in
            let data = doc.data()
            let name = data["name"] as? String ?? ""
            let email = data["email"] as? String ?? ""
            let cid = data["companyId"] as? String
            let roleRaw = data["role"] as? String ?? UserRole.viewer.rawValue
            let role = UserRole(rawValue: roleRaw) ?? .viewer
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            return UserDocument(
                id: doc.documentID,
                name: name,
                email: email,
                companyId: cid,
                role: role,
                createdAt: createdAt
            )
        }
    }
}
