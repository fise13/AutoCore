//
//  CompanyViewModel.swift
//  AutoCore
//

import Foundation
import Combine

@MainActor
final class CompanyViewModel: ObservableObject {
    @Published var currentCompany: CompanyDocument?
    @Published var errorMessage: String?
    
    private let companyService: CompanyService
    private let authViewModel: AuthViewModel
    
    init(companyService: CompanyService, authViewModel: AuthViewModel) {
        self.companyService = companyService
        self.authViewModel = authViewModel
    }
    
    func loadCurrentCompany() async {
        guard let companyId = authViewModel.currentUser?.companyId, !companyId.isEmpty else { return }
        do {
            currentCompany = try await companyService.fetchCompany(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createCompany(name: String) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            let company = try await companyService.createCompany(name: name, ownerId: userId)
            try await companyService.assignUserToCompany(userId: userId, companyId: company.id, role: .owner)
            currentCompany = company
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Использует общую компанию "default", чтобы Mac и iOS видели одни и те же данные бухгалтерии.
    func ensureDefaultCompany() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            try await companyService.ensureDefaultCompany(ownerId: userId)
            if let company = try await companyService.fetchCompany(companyId: "default") {
                currentCompany = company
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

