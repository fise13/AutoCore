import SwiftUI
import UniformTypeIdentifiers

/// Sheet view that lets the user pick an `.xlsx` file and displays
/// the strict JSON accounting analysis result.
struct AccountingAnalysisView: View {
    @StateObject private var viewModel = AccountingAnalysisViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Toolbar ──────────────────────────────────────────────
                header

                Divider()

                // ── Main content ─────────────────────────────────────────
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.jsonResult.isEmpty {
                    resultView
                } else {
                    emptyState
                }
            }
            .navigationTitle("Анализ Excel")
#if os(macOS)
            .navigationSubtitle("Бухгалтерия и товары")
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewModel.isShowingFilePicker = true
                    } label: {
                        Label("Выбрать файл", systemImage: "doc.badge.plus")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .fileImporter(
                isPresented: $viewModel.isShowingFilePicker,
                allowedContentTypes: viewModel.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.analyze(url: url)
                    }
                case .failure(let error):
                    // Surface the error directly — no side effects
                    _ = error
                }
            }
            .alert(
                "Ошибка анализа",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearResult() } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.clearResult() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Выберите .xlsx файл с листами «Проданные», «Доходы», «Расходы» или «Авансы».")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Анализируем данные…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Нажмите «Выбрать файл», чтобы загрузить Excel и получить JSON-анализ")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            // Copy button bar
            HStack {
                Text("Результат (JSON)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    copyToClipboard(viewModel.jsonResult)
                } label: {
                    Label("Скопировать", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                Button {
                    viewModel.clearResult()
                } label: {
                    Label("Очистить", systemImage: "trash")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                Text(viewModel.jsonResult)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#else
        UIPasteboard.general.string = text
#endif
    }
}

#if DEBUG
#Preview {
    AccountingAnalysisView()
}
#endif
