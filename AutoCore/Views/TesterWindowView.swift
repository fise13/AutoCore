import SwiftUI
#if os(macOS)
import AppKit

struct TesterWindowView: View {
    @ObservedObject var viewModel: TesterViewModel
    var onClose: () -> Void

    @State private var confirmClearEntireDatabase = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DSSpacing.x3) {
                    GroupBox(L10n.Tester.databaseStats) {
                        statsSection
                    }

                    GroupBox(L10n.Tester.dataCleanup) {
                        cleanupSection
                    }

                    GroupBox(L10n.Tester.firestoreMigration) {
                        migrationSection
                    }

                    GroupBox(L10n.Tester.utilities) {
                        utilitiesSection
                    }

                    messagesSection
                }
                .padding(DSSpacing.x3)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.Tester.close, action: onClose)
            }
        }
        .onAppear {
            viewModel.refreshStats()
        }
        .alert(L10n.Tester.confirmClearTitle, isPresented: $confirmClearEntireDatabase) {
            Button(L10n.Tester.cancel, role: .cancel) {}
            Button(L10n.Tester.confirmClearButton, role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text(L10n.Tester.confirmClearMessage)
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if viewModel.isLoading && viewModel.databaseStats == nil {
            ProgressView()
                .padding()
        } else if let stats = viewModel.databaseStats {
            VStack(alignment: .leading, spacing: DSSpacing.x2) {
                StatRow(label: L10n.Tester.brands, value: "\(stats.brandsCount)")
                StatRow(label: L10n.Tester.engines, value: "\(stats.enginesCount)")
                StatRow(label: L10n.Tester.motors, value: "\(stats.motorsCount)")
                StatRow(label: L10n.Tester.soldMotors, value: "\(stats.soldMotorsCount)")
                StatRow(label: L10n.Tester.serviceRecords, value: "\(stats.serviceRecordsCount)")
                StatRow(label: L10n.Tester.specificCategories, value: "\(stats.specificCategoriesCount)")
                StatRow(label: L10n.Tester.specificRecordsNew, value: "\(stats.specificRecordsCount)")

                if !stats.serviceRecordsByCategory.isEmpty {
                    Divider()
                    Text(L10n.Tester.byCategory)
                        .font(.headline)
                    ForEach(Array(stats.serviceRecordsByCategory.sorted(by: { $0.key < $1.key })), id: \.key) { category, count in
                        StatRow(label: category, value: "\(count)")
                            .padding(.leading, DSSpacing.x2)
                    }
                }
            }
            .padding(8)
        } else {
            Text(L10n.Tester.tapRefreshStats)
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private var cleanupSection: some View {
        VStack(spacing: DSSpacing.x2) {
            GroupBox(L10n.Tester.specificData) {
                VStack(spacing: DSSpacing.x2) {
                    TesterButton(
                        title: L10n.Tester.deleteAllSpecificCategories,
                        icon: "folder.fill",
                        color: .orange,
                        action: { viewModel.clearAllSpecificCategories() }
                    )
                    TesterButton(
                        title: L10n.Tester.deleteAllSpecificRecords,
                        icon: "doc.text",
                        color: .orange,
                        action: { viewModel.clearAllSpecificRecords() }
                    )
                    TesterButton(
                        title: L10n.Tester.deleteOldServiceRecords,
                        icon: "doc.text.below.ecg",
                        color: .orange,
                        action: { viewModel.clearAllServiceRecords() }
                    )
                }
                .padding(4)
            }

            Divider()

            TesterButton(
                title: L10n.Tester.deleteAllMotors,
                icon: "engine.combustion",
                color: .red,
                action: { viewModel.clearAllMotors() }
            )
            TesterButton(
                title: L10n.Tester.deleteAllEngines,
                icon: "gearshape",
                color: .red,
                action: { viewModel.clearAllEngines() }
            )
            TesterButton(
                title: L10n.Tester.deleteAllBrands,
                icon: "tag",
                color: .red,
                action: { viewModel.clearAllBrands() }
            )

            Divider()

            TesterButton(
                title: L10n.Tester.clearEntireDatabase,
                icon: "trash.fill",
                color: .red,
                isDestructive: true,
                action: { confirmClearEntireDatabase = true }
            )
        }
        .padding(8)
    }

    private var migrationSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.x2) {
            Text(L10n.Tester.firestoreMigrationHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            TesterButton(
                title: L10n.Tester.migrateOperations,
                icon: "cloud.fill",
                color: .blue,
                action: { viewModel.migrateFinancialOperationsToFirestore() }
            )
        }
        .padding(8)
    }

    private var utilitiesSection: some View {
        VStack(spacing: DSSpacing.x2) {
            Button(action: { viewModel.refreshStats() }) {
                Label(L10n.Tester.refreshStats, systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: {
                let info = viewModel.exportDatabaseInfo()
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(info, forType: .string)
            }) {
                Label(L10n.Tester.copyStats, systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Divider()

            Button(action: { viewModel.optimizeDatabase() }) {
                Label(L10n.Tester.optimizeDatabase, systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: { viewModel.exportDatabaseBackup() }) {
                Label(L10n.Tester.createBackup, systemImage: "externaldrive.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let error = viewModel.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .foregroundStyle(.red)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.1))
            .cornerRadius(8)
        }

        if let success = viewModel.successMessage {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(success)
                    .foregroundStyle(.green)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#endif

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

private struct TesterButton: View {
    let title: String
    let icon: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .foregroundStyle(isDestructive ? .white : .primary)
            .padding()
            .background(isDestructive ? color : color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
