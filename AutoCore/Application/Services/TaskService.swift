//
//  TaskService.swift
//  AutoCore
//

import Foundation

protocol TaskService {
    func createTask(_ task: TaskDocument) async throws
    func fetchCompanyTasks(companyId: String) async throws -> [TaskDocument]
}

