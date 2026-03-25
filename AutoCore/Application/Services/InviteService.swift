//
//  InviteService.swift
//  AutoCore
//

import Foundation

protocol InviteService {
    func createInvite(companyId: String, role: UserRole, createdBy: String, ttl: TimeInterval) async throws -> InviteDocument
    func validateInviteCode(_ code: String) async throws -> InviteDocument
    func markInviteUsed(_ inviteId: String) async throws
}

