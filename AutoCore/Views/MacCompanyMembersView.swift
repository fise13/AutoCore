//
//  MacCompanyMembersView.swift
//  AutoCore
//
//  macOS: список участников компании.
//

import SwiftUI

#if os(macOS)

struct MacCompanyMembersView: View {
    @StateObject private var viewModel: CompanyMembersViewModel
    @Environment(\.dismiss) private var dismiss

    init(companyId: String) {
        _viewModel = StateObject(wrappedValue: CompanyMembersViewModel(
            membersService: FirestoreCompanyMembersService(),
            companyId: companyId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Участники компании")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView("Загрузка…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.members.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Пока нет сотрудников")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.members, id: \.id) { member in
                    memberRow(member)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 400, minHeight: 320)
        .task { await viewModel.load() }
    }

    private func memberRow(_ member: UserDocument) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String((member.name.isEmpty ? member.email : member.name).prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name.isEmpty ? member.email : member.name)
                    .font(.subheadline.weight(.medium))
                if !member.name.isEmpty && !member.email.isEmpty {
                    Text(member.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(member.role.localizedDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#endif
