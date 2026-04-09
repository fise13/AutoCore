import SwiftUI
import UIKit

#if os(iOS)

struct IOSInviteManagementView: View {
    @StateObject private var viewModel: InviteManagementViewModel
    @Environment(\.dismiss) private var dismiss

    init(authViewModel: AuthViewModel) {
        _viewModel = StateObject(
            wrappedValue: InviteManagementViewModel(
                inviteService: FirestoreInviteService(),
                authViewModel: authViewModel
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IOSScreenBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        IOSFlowlyHeader(title: "Invite", subtitle: "Создание кода приглашения", onBack: nil)
                            .overlay(alignment: .topTrailing) {
                                Button("Готово") { dismiss() }
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.top, 60)
                                    .padding(.trailing, Spacing.x3)
                            }

                        VStack(spacing: Spacing.x3) {
                            IOSFlowlyCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Роль")
                                        .font(IOSDesign.Typography.subtitle.weight(.semibold))
                                        .foregroundStyle(IOSPalette.textPrimary)
                                    rolePicker

                                    Text("Срок (часы): \(Int(viewModel.ttlHours))")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(IOSPalette.textSecondary)
                                    Slider(value: $viewModel.ttlHours, in: 6...168, step: 6)
                                        .tint(IOSPalette.flowlyBlue)
                                }
                            }

                            if let code = viewModel.generatedCode {
                                IOSFlowlyCard {
                                    VStack(spacing: 10) {
                                        Text("Код приглашения")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(IOSPalette.textSecondary)
                                        Text(code)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundStyle(IOSPalette.textPrimary)
                                            .tracking(2)
                                        Button {
                                            UIPasteboard.general.string = code
                                            IOSHaptics.notification(.success)
                                        } label: {
                                            Label("Скопировать", systemImage: "doc.on.doc")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(IOSSecondaryButtonStyle())
                                    }
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            if let error = viewModel.errorMessage {
                                IOSStatusBanner(type: .error, message: error)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            Button {
                                Task { await viewModel.createInvite() }
                            } label: {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text(viewModel.isLoading ? "Создание..." : "Создать invite-код")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(IOSPrimaryButtonStyle())
                            .disabled(viewModel.isLoading)
                        }
                        .padding(Spacing.x3)
                    }
                }
            }
        }
    }

    private var rolePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UserRole.allCases, id: \.rawValue) { role in
                    Button {
                        withAnimation(IOSMotion.standard) {
                            viewModel.selectedRole = role
                        }
                    } label: {
                        IOSTagChip(
                            text: role.localizedDisplayName,
                            style: viewModel.selectedRole == role ? .accent : .neutral,
                            systemImage: "person.crop.circle.badge.checkmark",
                            isSelected: viewModel.selectedRole == role
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#endif
