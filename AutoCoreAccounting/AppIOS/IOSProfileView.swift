//
//  IOSProfileView.swift
//  AutoCoreAccounting
//
//  Профиль в стиле Flowly для iOS.
//

import SwiftUI

#if os(iOS)

struct IOSProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onDismiss: () -> Void

    @State private var displayName: String = ""
    @FocusState private var focusedField: Bool
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            IOSScreenBackground()
            VStack(spacing: 0) {
                headerSection
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.x3) {
                        if let user = authViewModel.currentUser {
                            profileCard(user: user)
                            deleteAccountSection
                            if let msg = authViewModel.errorMessage {
                                errorBanner(msg)
                            }
                        }
                    }
                    .padding(Spacing.x3)
                }
                .alert("Удалить аккаунт?", isPresented: $showDeleteConfirmation) {
                    Button("Отмена", role: .cancel) { }
                    Button("Удалить", role: .destructive) {
                        Task {
                            isDeleting = true
                            await authViewModel.deleteAccount()
                            isDeleting = false
                            if authViewModel.currentUser == nil {
                                onDismiss()
                            }
                        }
                    }
                } message: {
                    Text("Все данные аккаунта будут удалены безвозвратно. Это действие нельзя отменить.")
                }
            }
        }
        .onAppear {
            displayName = authViewModel.currentUser?.displayName ?? ""
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
            IOSPalette.flowlyBlue
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)
            VStack(alignment: .leading, spacing: 4) {
                Text("Профиль")
                    .font(IOSDesign.Typography.title)
                    .foregroundStyle(.white)
                Text("Редактирование данных")
                    .font(IOSDesign.Typography.subtitle)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.x3)
            .padding(.top, 60)
            .padding(.bottom, Spacing.x3)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.top, 56)
            .padding(.trailing, Spacing.x3)
        }
    }

    private func profileCard(user: UserEntity) -> some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                if !user.email.isEmpty {
                    labelValueRow(label: "Email", value: user.email)
                }
                labelValueRow(label: "Роль", value: user.role.displayName)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Имя")
                        .font(IOSDesign.Typography.subtitle.weight(.semibold))
                        .foregroundStyle(IOSPalette.textSecondary)
                    TextField("Введите имя", text: $displayName)
                        .font(IOSDesign.Typography.body)
                        .foregroundStyle(IOSPalette.textPrimary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                                .fill(IOSPalette.backgroundBase)
                                .overlay(
                                    RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                                        .stroke(IOSPalette.border, lineWidth: 1)
                                )
                        )
                        .focused($focusedField)
                }

                Button {
                    Task {
                        await authViewModel.updateProfile(displayName: displayName.isEmpty ? nil : displayName)
                        if authViewModel.errorMessage == nil {
                            onDismiss()
                        }
                    }
                } label: {
                    Text("Сохранить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IOSPrimaryButtonStyle())
                .disabled(displayName == (user.displayName ?? ""))
                .opacity(displayName == (user.displayName ?? "") ? 0.6 : 1)
            }
        }
    }

    private func labelValueRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(IOSDesign.Typography.subtitle.weight(.semibold))
                .foregroundStyle(IOSPalette.textSecondary)
            Text(value)
                .font(IOSDesign.Typography.body)
                .foregroundStyle(IOSPalette.textPrimary)
        }
    }

    private var deleteAccountSection: some View {
        IOSFlowlyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Удаление аккаунта")
                    .font(IOSDesign.Typography.subtitle.weight(.semibold))
                    .foregroundStyle(IOSPalette.textPrimary)
                Text("Удаление аккаунта приведёт к безвозвратному удалению вашего профиля и привязки к компании.")
                    .font(.caption)
                    .foregroundStyle(IOSPalette.textSecondary)
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Text("Удалить аккаунт")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(IOSPalette.negative)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(IOSPalette.negative)
            Text(msg)
                .font(.caption)
                .foregroundStyle(IOSPalette.negative)
        }
        .padding(Spacing.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: IOSDesign.Radius.button, style: .continuous)
                .fill(IOSPalette.negative.opacity(0.12))
        )
    }
}

#endif
