//
//  CompanyMembershipService.swift
//  AutoCore
//

import Foundation

protocol CompanyMembershipService {
    func joinCompany(with inviteCode: String, userId: String) async throws
}

