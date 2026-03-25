//
//  InviteViewModel.swift
//  AutoCore
//

import Foundation
import Combine

@MainActor
final class InviteViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let membershipService: CompanyMembershipService
    private let authViewModel: AuthViewModel
    
    init(membershipService: CompanyMembershipService, authViewModel: AuthViewModel) {
        self.membershipService = membershipService
        self.authViewModel = authViewModel
    }
    
    func joinCompanyWithCode(code: String) async {
        guard let userId = authViewModel.currentUser?.id else {
            errorMessage = "Необходим вход в систему"
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await membershipService.joinCompany(with: code, userId: userId)
            successMessage = "Вы успешно присоединились к компании"
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

