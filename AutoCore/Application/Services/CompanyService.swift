//
//  CompanyService.swift
//  AutoCore
//

import Foundation

protocol CompanyService {
    func createCompany(name: String, ownerId: String) async throws -> CompanyDocument
    /// Создаёт или использует компанию "default", привязывает пользователя. Нужно, чтобы Mac и iOS видели одни и те же данные (company_id = default).
    func ensureDefaultCompany(ownerId: String) async throws
    func fetchCompany(companyId: String) async throws -> CompanyDocument?
    func assignUserToCompany(userId: String, companyId: String, role: UserRole) async throws
}

