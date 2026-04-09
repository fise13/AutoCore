import Foundation
import Combine

@MainActor
final class InviteManagementViewModel: ObservableObject {
    @Published var selectedRole: UserRole = .accountant
    @Published var ttlHours: Double = 72
    @Published var generatedCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let inviteService: InviteService
    private let authViewModel: AuthViewModel

    init(inviteService: InviteService, authViewModel: AuthViewModel) {
        self.inviteService = inviteService
        self.authViewModel = authViewModel
    }

    func createInvite() async {
        guard let user = authViewModel.currentUser else {
            errorMessage = "Необходим вход в систему"
            return
        }
        guard !user.companyId.isEmpty else {
            errorMessage = "Сначала выберите или создайте компанию"
            return
        }

        isLoading = true
        errorMessage = nil
        generatedCode = nil
        defer { isLoading = false }

        do {
            await authViewModel.syncCompanyIdToFirestoreIfNeeded(companyId: user.companyId)
            await authViewModel.refreshCurrentUser()
            
            guard let refreshedUser = authViewModel.currentUser else {
                errorMessage = "Не удалось обновить профиль пользователя"
                return
            }
            guard refreshedUser.role == .owner || refreshedUser.role == .admin else {
                errorMessage = "Создавать invite-коды могут только владелец или администратор компании"
                return
            }
            
            let invite = try await inviteService.createInvite(
                companyId: refreshedUser.companyId,
                role: selectedRole,
                createdBy: refreshedUser.id,
                ttl: ttlHours * 3600
            )
            generatedCode = invite.code
        } catch let error as AuthError {
            errorMessage = error.localizedMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
