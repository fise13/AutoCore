//
//  OnboardingView.swift
//  AutoCore
//
//  macOS: выбор создать компанию или присоединиться по invite-коду.
//

import SwiftUI

#if os(macOS)

struct OnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var companyViewModel: CompanyViewModel
    @StateObject private var inviteViewModel: InviteViewModel
    
    @State private var choice: OnboardingChoice = .choose
    @State private var companyName = ""
    
    enum OnboardingChoice {
        case choose
        case create
        case join
    }
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        _companyViewModel = StateObject(wrappedValue: CompanyViewModel(
            companyService: FirestoreCompanyService(),
            authViewModel: authViewModel
        ))
        _inviteViewModel = StateObject(wrappedValue: InviteViewModel(
            membershipService: FirestoreCompanyMembershipService(inviteService: FirestoreInviteService()),
            authViewModel: authViewModel
        ))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(L10n.Onboarding.welcome)
                .font(.title)

            Text(L10n.Onboarding.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            
            switch choice {
            case .choose:
                VStack(spacing: 12) {
                    Button {
                        choice = .create
                    } label: {
                        Label(L10n.Onboarding.createCompany, systemImage: "building.2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: 260)
                    
                    Button {
                        choice = .join
                    } label: {
                        Label(L10n.Onboarding.haveInviteCode, systemImage: "person.badge.key")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 260)
                }
                .padding(.top, 16)
                
            case .create:
                createCompanyForm
                
            case .join:
                joinCompanyForm
            }
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 320)
    }
    
    private var createCompanyForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                choice = .choose
                companyName = ""
                companyViewModel.errorMessage = nil
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            
            Text(L10n.Onboarding.companyName)
                .font(.headline)

            TextField(L10n.Onboarding.companyNamePlaceholder, text: $companyName)
                .textFieldStyle(.roundedBorder)
            
            if let error = companyViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Button {
                Task {
                    await companyViewModel.createCompany(name: companyName.trimmingCharacters(in: .whitespacesAndNewlines))
                    if companyViewModel.errorMessage == nil {
                        await authViewModel.refreshCurrentUser()
                    }
                }
            } label: {
                if companyViewModel.currentCompany != nil {
                    Text(L10n.Onboarding.done)
                } else {
                    Text(L10n.Onboarding.create)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .frame(maxWidth: 320)
    }
    
    private var joinCompanyForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                choice = .choose
                inviteViewModel.code = ""
                inviteViewModel.errorMessage = nil
                inviteViewModel.successMessage = nil
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            
            JoinCompanyView(viewModel: inviteViewModel)
            
            if inviteViewModel.successMessage != nil {
                Button(L10n.Onboarding.continue_) {
                    Task {
                        await authViewModel.refreshCurrentUser()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: 320)
    }
}

#endif
