import Foundation
import UIKit

#if os(iOS)

final class InvoiceScannerService {
    private let aiService = AIExtractionService()

    /// AI-first pipeline: Image -> AI structured extraction -> ScannedInvoice.
    /// OCR используется как fallback внутри AIExtractionService.
    func scanImage(image: UIImage) async throws -> ScannedInvoice {
        try await aiService.extract(from: image)
    }
}

#endif
