//
//  CompanyMembersViewModel.swift
//  AutoCore
//

import Foundation
import Combine

@MainActor
final class CompanyMembersViewModel: ObservableObject {
    @Published private(set) var members: [UserDocument] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let membersService: CompanyMembersService
    private let companyId: String

    init(membersService: CompanyMembersService, companyId: String) {
        self.membersService = membersService
        self.companyId = companyId
    }

    func load() async {
        guard !companyId.isEmpty else {
            members = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            members = try await membersService.fetchMembers(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
            members = []
        }
    }
}
