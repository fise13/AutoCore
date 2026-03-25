//
//  FirestoreTaskService.swift
//  AutoCore
//

import Foundation
import FirebaseFirestore

final class FirestoreTaskService: TaskService {
    private let db = Firestore.firestore()
    
    func createTask(_ task: TaskDocument) async throws {
        let data: [String: Any] = [
            "companyId": task.companyId,
            "title": task.title,
            "description": task.description,
            "status": task.status.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        var finalData = data
        if let assignedTo = task.assignedTo {
            finalData["assignedTo"] = assignedTo
        }
        _ = try await db.collection("tasks").addDocument(data: finalData)
    }
    
    func fetchCompanyTasks(companyId: String) async throws -> [TaskDocument] {
        let snapshot = try await db.collection("tasks")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let cid = data["companyId"] as? String,
                let title = data["title"] as? String,
                let description = data["description"] as? String,
                let statusRaw = data["status"] as? String,
                let status = TaskStatus(rawValue: statusRaw)
            else {
                return nil
            }
            let assignedTo = data["assignedTo"] as? String
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            return TaskDocument(
                id: doc.documentID,
                companyId: cid,
                title: title,
                description: description,
                assignedTo: assignedTo,
                status: status,
                createdAt: createdAt
            )
        }
    }
}

