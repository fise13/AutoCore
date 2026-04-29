import Foundation
import Combine
import UniformTypeIdentifiers

/// ViewModel that drives the Excel accounting analysis UI.
/// Orchestrates file picking → ExcelAccountingAnalysisService → JSON display.
@MainActor
final class AccountingAnalysisViewModel: ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var jsonResult: String = ""
    @Published private(set) var errorMessage: String? = nil
    @Published var isShowingFilePicker = false

    private let service = ExcelAccountingAnalysisService()

    // MARK: - Public

    func analyze(url: URL) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        jsonResult = ""

        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) { [service] in
                    // Security-scope the URL so sandboxed apps can open it.
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    return try service.analyzeToJSON(url: url)
                }.value

                jsonResult  = String(data: data, encoding: .utf8) ?? ""
                isLoading   = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading    = false
            }
        }
    }

    func clearResult() {
        jsonResult   = ""
        errorMessage = nil
    }

    /// UTType filter for the file picker — only `.xlsx` files.
    var allowedContentTypes: [UTType] {
        [UTType(filenameExtension: "xlsx") ?? .spreadsheet]
    }
}
