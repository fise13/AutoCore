import Foundation
import Vision

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// AI-powered invoice extraction service.
/// Works identically on iOS and macOS — same OpenRouter API, same prompt.
/// Image input type is platform-conditional: UIImage on iOS, NSImage on macOS.
final class AIExtractionService {

    // MARK: - OpenRouter API models

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        struct ResponseFormat: Encodable {
            let type: String
        }
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: ResponseFormat?
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    // MARK: - Configuration

    private let session: URLSession
    private let baseURL: URL
    private let model: String
    private let apiKey: String

    init(session: URLSession = .shared) {
        self.session = session
        let env = ProcessInfo.processInfo.environment
        let configuredBase = env["OPENROUTER_BASE_URL"] ?? "https://openrouter.ai/api/v1"
        self.baseURL = URL(string: configuredBase) ?? URL(string: "https://openrouter.ai/api/v1")!
        self.model   = env["OPENROUTER_MODEL"]   ?? "openai/gpt-4o-mini"
        self.apiKey  = OpenRouterKeyProvider.resolved
    }

    // MARK: - iOS entry point

#if os(iOS)
    func extract(from image: UIImage) async throws -> ScannedInvoice {
        let cgImage = image.cgImage
        let base64  = image.jpegData(compressionQuality: 0.85)?.base64EncodedString() ?? ""
        return try await extractFromCGImage(cgImage, base64: base64)
    }
#endif

    // MARK: - macOS entry point

#if os(macOS)
    func extract(from image: NSImage) async throws -> ScannedInvoice {
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else {
            throw NSError(domain: "AIExtraction", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось конвертировать изображение в JPEG."])
        }
        let base64 = jpegData.base64EncodedString()
        return try await extractFromCGImage(cgImage, base64: base64)
    }
#endif

    // MARK: - Shared pipeline

    private func extractFromCGImage(_ cgImage: CGImage?, base64: String) async throws -> ScannedInvoice {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "AIExtraction", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "API ключ не настроен (OPENROUTER_API_KEY)."])
        }

        let ocrText = cgImage.map { extractTextWithVision(from: $0) }

        do {
            let response = try await requestAI(input: "IMAGE_BASE64:\n\(base64)")
            let transaction = AITransactionMapper.mapToTransaction(response)
            return AITransactionMapper.mapToScannedInvoice(
                transaction,
                rawText: ocrText,
                confidence: response.confidence
            )
        } catch {
            guard let text = ocrText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw error }
            let response = try await requestAI(input: "OCR_TEXT:\n\(text)")
            let transaction = AITransactionMapper.mapToTransaction(response)
            return AITransactionMapper.mapToScannedInvoice(
                transaction,
                rawText: text,
                confidence: response.confidence
            )
        }
    }

    // MARK: - API call

    private func requestAI(input: String) async throws -> AITransactionResponse {
        let prompt = """
        You are analyzing a financial document from an auto service business.
        Extract structured data from the input.

        Rules:
        - If it's a "Заказ-наряд" -> it's income
        - If it's a purchase invoice -> it's expense
        - Normalize numbers (remove spaces, convert to float)
        - Return ONLY valid JSON

        JSON format:
        {
          "type": "income | expense",
          "date": "YYYY-MM-DD",
          "counterparty": "string",
          "items": [
            { "name": "string", "quantity": number, "price": number, "total": number }
          ],
          "total": number,
          "confidence": 0.0
        }
        """

        let payload = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: prompt),
                .init(role: "user",   content: input)
            ],
            temperature: 0.1,
            response_format: .init(type: "json_object")
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "AIExtraction", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "AI API вернул ошибку."])
        }

        let chat      = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content   = chat.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let jsonText  = sanitizeJSON(content)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "AIExtraction", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Пустой ответ от AI."])
        }
        return try JSONDecoder().decode(AITransactionResponse.self, from: jsonData)
    }

    // MARK: - Vision OCR (cross-platform)

    private func extractTextWithVision(from cgImage: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel    = .accurate
        request.usesLanguageCorrection  = true
        request.recognitionLanguages    = ["ru-RU", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func sanitizeJSON(_ text: String) -> String {
        var out = text
        if out.hasPrefix("```") {
            out = out.replacingOccurrences(of: "```json", with: "")
            out = out.replacingOccurrences(of: "```",     with: "")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
