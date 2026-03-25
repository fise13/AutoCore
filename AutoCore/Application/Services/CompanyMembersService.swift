//
//  CompanyMembersService.swift
//  AutoCore
//

import Foundation

protocol CompanyMembersService {
    func fetchMembers(companyId: String) async throws -> [UserDocument]
}
