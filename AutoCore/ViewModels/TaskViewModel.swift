//
//  TaskViewModel.swift
//  AutoCore
//

import Foundation
import Combine

@MainActor
final class TaskViewModel: ObservableObject {
    @Published var tasks: [TaskDocument] = []
    @Published var errorMessage: String?
    
    private let taskService: TaskService
    private let authViewModel: AuthViewModel
    
    init(taskService: TaskService, authViewModel: AuthViewModel) {
        self.taskService = taskService
        self.authViewModel = authViewModel
    }
    
    func loadTasks() async {
        guard let companyId = authViewModel.currentUser?.companyId, !companyId.isEmpty else { return }
        do {
            tasks = try await taskService.fetchCompanyTasks(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createTask(title: String, description: String, assignedTo: String?) async {
        guard let companyId = authViewModel.currentUser?.companyId, !companyId.isEmpty else { return }
        let task = TaskDocument(
            id: UUID().uuidString,
            companyId: companyId,
            title: title,
            description: description,
            assignedTo: assignedTo,
            status: .open,
            createdAt: nil
        )
        do {
            try await taskService.createTask(task)
            await loadTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

