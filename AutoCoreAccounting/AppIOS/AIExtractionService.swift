import Foundation
import UIKit
import Vision

#if os(iOS)

final class AIExtractionService {
    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: ResponseFormat?

        struct ResponseFormat: Encodable {
            let type: String
        }
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

    private let session: URLSession
    private let baseURL: URL
    private let model: String
    private let apiKey: String

    init(session: URLSession = .shared) {
        self.session = session
        let env = ProcessInfo.processInfo.environment
        let configuredBase = env["OPENROUTER_BASE_URL"] ?? "https://openrouter.ai/api/v1"
        self.baseURL = URL(string: configuredBase) ?? URL(string: "https://openrouter.ai/api/v1")!
        self.model = env["OPENROUTER_MODEL"] ?? "openai/gpt-4o-mini"
        self.apiKey = env["OPENROUTER_API_KEY"] ?? env["OPENAI_API_KEY"] ?? "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"
    }

    func extract(from image: UIImage) async throws -> ScannedInvoice {
        guard !apiKey.isEmpty else {
            throw NSError(
                domain: "AIExtraction",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "API ключ для AI не настроен (OPENROUTER_API_KEY/OPENAI_API_KEY)."]
            )
        }

        let ocrText = await extractTextWithVision(from: image)
        do {
            let dataURL = imageDataURL(image)
            let response = try await requestAI(input: "IMAGE_BASE64:\n\(dataURL)")
            let transaction = AITransactionMapper.mapToTransaction(response)
            return AITransactionMapper.mapToScannedInvoice(
                transaction,
                rawText: ocrText,
                confidence: response.confidence
            )
        } catch {
            // Fallback: если не удалось по изображению, отправляем текст OCR в AI.
            guard let ocrText, !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw error }
            let response = try await requestAI(input: "OCR_TEXT:\n\(ocrText)")
            let transaction = AITransactionMapper.mapToTransaction(response)
            return AITransactionMapper.mapToScannedInvoice(
                transaction,
                rawText: ocrText,
                confidence: response.confidence
            )
        }
    }

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
            {
              "name": "string",
              "quantity": number,
              "price": number,
              "total": number
            }
          ],
          "total": number,
          "confidence": 0.0
        }
        """

        let payload = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: prompt),
                .init(role: "user", content: input)
            ],
            temperature: 0.1,
            response_format: .init(type: "json_object")
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "AIExtraction", code: -2, userInfo: [NSLocalizedDescriptionKey: "AI API error"])
        }

        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = chat.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let jsonText = sanitizeJSON(content)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "AIExtraction", code: -3, userInfo: [NSLocalizedDescriptionKey: "AI response is empty"])
        }
        return try JSONDecoder().decode(AITransactionResponse.self, from: jsonData)
    }

    private func sanitizeJSON(_ text: String) -> String {
        var out = text
        if out.hasPrefix("```") {
            out = out.replacingOccurrences(of: "```json", with: "")
            out = out.replacingOccurrences(of: "```", with: "")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func imageDataURL(_ image: UIImage) -> String {
        let data = image.jpegData(compressionQuality: 0.85) ?? Data()
        return data.base64EncodedString()
    }

    private func extractTextWithVision(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ru-RU", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return nil }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        } catch {
            return nil
        }
    }
}

#endif
