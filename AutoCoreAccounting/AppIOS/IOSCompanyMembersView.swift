//
//  IOSCompanyMembersView.swift
//  AutoCoreAccounting
//
//  Список сотрудников компании. Только для owner/admin.
//

import SwiftUI

#if os(iOS)

struct IOSCompanyMembersView: View {
    @StateObject private var viewModel: CompanyMembersViewModel
    @Environment(\.dismiss) private var dismiss

    init(companyId: String) {
        _viewModel = StateObject(wrappedValue: CompanyMembersViewModel(
            membersService: FirestoreCompanyMembersService(),
            companyId: companyId
        ))
    }

    var body: some View {
        ZStack {
            IOSScreenBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    IOSFlowlyHeader(title: "Сотрудники", subtitle: "Участники вашей компании", onBack: { dismiss() })
                        .frame(height: 140)

                    VStack(spacing: Spacing.x3) {
                        if viewModel.isLoading && viewModel.members.isEmpty {
                            ProgressView("Загрузка…")
                                .padding(Spacing.x3)
                        } else if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(IOSPalette.negative)
                                .padding()
                        } else if viewModel.members.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48))
                                    .foregroundStyle(IOSPalette.textSecondary)
                                Text("Пока нет сотрудников")
                                    .font(IOSDesign.Typography.subtitle)
                                    .foregroundStyle(IOSPalette.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.x3)
                        } else {
                            IOSFlowlyCard {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.members, id: \.id) { member in
                                        memberRow(member)
                                        if member.id != viewModel.members.last?.id {
                                            Divider().overlay(IOSPalette.border).padding(.leading, 56)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Spacing.x3)
                }
            }
        }
        .task { await viewModel.load() }
    }

    private func memberRow(_ member: UserDocument) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(IOSPalette.flowlyBlue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String((member.name.isEmpty ? member.email : member.name).prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSPalette.flowlyBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name.isEmpty ? member.email : member.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(IOSPalette.textPrimary)
                if !member.name.isEmpty && !member.email.isEmpty {
                    Text(member.email)
                        .font(.caption)
                        .foregroundStyle(IOSPalette.textSecondary)
                }
                Text(member.role.localizedDisplayName)
                    .font(.caption2)
                    .foregroundStyle(IOSPalette.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(IOSPalette.backgroundElevated)
                    .cornerRadius(4)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

#endif
