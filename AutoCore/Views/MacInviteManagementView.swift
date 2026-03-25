//
//  MacInviteManagementView.swift
//  AutoCore
//
//  macOS: создание кода приглашения в компанию.
//

import SwiftUI

#if os(macOS)
import AppKit

struct MacInviteManagementView: View {
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
        VStack(spacing: 24) {
            HStack {
                Text("Приглашения")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Роль")
                    .font(.headline)
                Picker("Роль", selection: $viewModel.selectedRole) {
                    ForEach(UserRole.allCases, id: \.rawValue) { role in
                        Text(role.localizedDisplayName).tag(role)
                    }
                }
                .pickerStyle(.segmented)

                Text("Срок (часы): \(Int(viewModel.ttlHours))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.ttlHours, in: 6...168, step: 6)
            }

            if let code = viewModel.generatedCode {
                VStack(spacing: 12) {
                    Text("Код приглашения")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(2)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    } label: {
                        Label("Скопировать", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.createInvite() }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.isLoading ? "Создание…" : "Создать invite-код")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 320)
    }
}

#endif
