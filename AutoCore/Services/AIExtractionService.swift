import Foundation
import Vision

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// AI-powered invoice extraction service.
/// Uses the OpenRouter API (compatible with OpenAI) — same endpoint on iOS and macOS.
/// Vision OCR is used both as a pre-processing step and as a fallback.
final class AIExtractionService {

    // MARK: - OpenRouter API shapes

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        struct ResponseFormat: Encodable { let type: String }
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: ResponseFormat?
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg
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
        let base = env["OPENROUTER_BASE_URL"] ?? "https://openrouter.ai/api/v1"
        self.baseURL = URL(string: base) ?? URL(string: "https://openrouter.ai/api/v1")!
        self.model   = env["OPENROUTER_MODEL"]   ?? "openai/gpt-4o-mini"
        self.apiKey  = OpenRouterKeyProvider.resolved
    }

    // MARK: - Platform-specific entry points

#if os(macOS)
    /// macOS entry point: accepts NSImage.
    func extract(from image: NSImage) async throws -> ScannedInvoice {
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let jpegData: Data? = {
            guard let tiff = image.tiffRepresentation,
                  let rep  = NSBitmapImageRep(data: tiff)
            else { return nil }
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }()
        let base64 = jpegData?.base64EncodedString() ?? ""
        return try await pipeline(cgImage: cgImage, base64: base64)
    }
#elseif os(iOS)
    /// iOS entry point: accepts UIImage.
    func extract(from image: UIImage) async throws -> ScannedInvoice {
        let cgImage = image.cgImage
        let base64  = image.jpegData(compressionQuality: 0.85)?.base64EncodedString() ?? ""
        return try await pipeline(cgImage: cgImage, base64: base64)
    }
#endif

    // MARK: - Shared pipeline

    private func pipeline(cgImage: CGImage?, base64: String) async throws -> ScannedInvoice {
        guard !apiKey.isEmpty else {
            let msg = """
            API ключ не настроен. Укажите OPENROUTER_API_KEY или OPENAI_API_KEY (среда запуска / defaults write для fise.AutoCore), затем перезапустите приложение.
            """
            throw NSError(domain: "AIExtraction", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let ocrText = cgImage.flatMap { extractTextWithVision(from: $0) }

        do {
            let response    = try await callAPI(input: "IMAGE_BASE64:\n\(base64)")
            let transaction = AITransactionMapper.mapToTransaction(response)
            return AITransactionMapper.mapToScannedInvoice(
                transaction, rawText: ocrText, confidence: response.confidence)
        } catch {
            // Fallback to OCR text if the image call fails
            guard let text = ocrText,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw error }
            let response    = try await callAPI(input: "OCR_TEXT:\n\(text)")
            let transaction = AITransactionMapper.mapToTransaction(response)
            return AITransactionMapper.mapToScannedInvoice(
                transaction, rawText: text, confidence: response.confidence)
        }
    }

    // MARK: - API call

    private func callAPI(input: String) async throws -> AITransactionResponse {
        let prompt = """
        You are analyzing a financial document from an auto service business.
        Extract structured data from the input.

        Rules:
        - If it's a "Заказ-наряд" → it's income
        - If it's a purchase invoice → it's expense
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let u = error as? URLError {
                throw aiError(
                    code: 1,
                    summary: "Сеть: \(u.localizedDescription) (код \(u.errorCode))",
                    detail: "Проверьте интернет, прокси и доступ к \(self.baseURL.host ?? "api")."
                )
            }
            throw aiError(
                code: 1,
                summary: "Запрос не выполнен: \(error.localizedDescription)",
                detail: "Эндпоинт: \(self.baseURL.appendingPathComponent("chat/completions").absoluteString)"
            )
        }
        let endpoint = request.url?.absoluteString ?? "chat/completions"
        guard let http = response as? HTTPURLResponse else {
            let raw = self.dataPreview(data)
            throw aiError(code: 2, summary: "Ответ не HTTP", detail: "Эндпоинт: \(endpoint)\nФрагмент: \(raw)")
        }
        if !(200...299).contains(http.statusCode) {
            let raw = self.dataPreview(data, max: 1_800)
            throw aiError(
                code: 3,
                summary: "HTTP \(http.statusCode) от OpenRouter/модели",
                detail: "Модель: \(model)\nЭндпоинт: \(endpoint)\n\nТело ответа:\n\(raw)"
            )
        }
        let chat: ChatResponse
        do {
            chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            let raw = self.dataPreview(data, max: 1_200)
            throw aiError(
                code: 4,
                summary: "Не удалось разобрать JSON чата: \(error.localizedDescription)",
                detail: "Модель: \(model)\n\(raw)"
            )
        }
        let content  = chat.choices.first?.message.content?
                           .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let jsonText = sanitizeJSON(content)
        guard let jsonData = jsonText.data(using: .utf8) else {
            let hint = String(content.prefix(500))
            throw aiError(
                code: 5,
                summary: "Пустой или не-UTF8 ответ content от модели",
                detail: "Первые символы: \(hint.isEmpty ? "∅" : hint)"
            )
        }
        do {
            return try JSONDecoder().decode(AITransactionResponse.self, from: jsonData)
        } catch {
            let raw = String(jsonText.prefix(800))
            throw aiError(
                code: 6,
                summary: "JSON чека/документа не соответствует схеме: \(error.localizedDescription)",
                detail: "Первый фрагмент ответа:\n\(raw)"
            )
        }
    }

    private func dataPreview(_ data: Data, max: Int = 1_200) -> String {
        if let t = String(data: data, encoding: .utf8) {
            return t.count <= max ? t : String(t.prefix(max)) + "…"
        }
        return "двоичные \(data.count) байт"
    }

    private func aiError(code: Int, summary: String, detail: String) -> NSError {
        let full = "\(summary)\n\n\(detail)"
        return NSError(
            domain: "AIExtraction",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: full, "detail": detail]
        )
    }

    // MARK: - Vision OCR (cross-platform; Vision.framework is available on both iOS and macOS)

    private func extractTextWithVision(from cgImage: CGImage) -> String? {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel       = .accurate
        req.usesLanguageCorrection = true
        req.recognitionLanguages   = ["ru-RU", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([req])
            let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.joined(separator: "\n")
                              .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        } catch {
            return nil
        }
    }

    private func sanitizeJSON(_ text: String) -> String {
        var s = text
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
            s = s.replacingOccurrences(of: "```",     with: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Shared decodable response & mapper

struct AITransactionResponse: Decodable {
    let type: String
    let date: String
    let counterparty: String?
    let items: [AIItem]
    let total: Double
    let confidence: Double?
}

struct AIItem: Decodable {
    let name: String
    let quantity: Double?
    let price: Double?
    let total: Double?
}

enum AITransactionMapper {

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone.current
        return f
    }()

    static func mapToTransaction(_ r: AITransactionResponse) -> (
        type: InvoiceDocumentType,
        date: Date,
        counterparty: String?,
        items: [AIItem],
        total: Double
    ) {
        let type: InvoiceDocumentType = r.type.lowercased() == "income" ? .income : .expense
        let date = isoFormatter.date(from: r.date) ?? Date()
        return (type, date, r.counterparty, r.items, r.total)
    }

    static func mapToScannedInvoice(
        _ t: (type: InvoiceDocumentType, date: Date, counterparty: String?, items: [AIItem], total: Double),
        rawText: String?,
        confidence: Double?
    ) -> ScannedInvoice {
        let invoiceItems = t.items.map { item -> InvoiceItem in
            let qty = Decimal(item.quantity ?? 1)
            let price: Decimal
            if let p = item.price {
                price = Decimal(p)
            } else if let tot = item.total, (item.quantity ?? 0) > 0 {
                price = Decimal(tot / (item.quantity ?? 1))
            } else {
                price = 0
            }
            return InvoiceItem(name: item.name, quantity: qty, price: price)
        }

        let docKind: InvoiceDocumentKind = t.type == .income ? .workOrder : .invoice
        let conf     = deriveConfidence(items: t.items, total: t.total, provided: confidence)
        let warnings = buildWarnings(items: t.items, total: t.total, confidence: conf)

        return ScannedInvoice(
            scannedAt:    t.date,
            type:         t.type,
            documentKind: docKind,
            counterparty: t.counterparty,
            items:        invoiceItems,
            rawText:      rawText,
            aiWarnings:   warnings,
            aiConfidence: conf
        )
    }

    static func buildWarnings(items: [AIItem], total: Double, confidence: Double?) -> [String] {
        var w: [String] = []
        let sum = items.compactMap(\.total).reduce(0, +)
        if abs(sum - total) > 0.5 {
            w.append("Сумма позиций (\(sum)) не совпадает с итогом (\(total)).")
        }
        if let c = confidence, c < 0.65 {
            w.append("Низкая уверенность AI (\(Int(c * 100))%). Нужна ручная проверка.")
        }
        return w
    }

    static func deriveConfidence(items: [AIItem], total: Double, provided: Double?) -> Double {
        if let p = provided { return max(0, min(1, p)) }
        var score = 0.45
        if !items.isEmpty { score += 0.2 }
        let named = items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        if !items.isEmpty { score += (Double(named) / Double(items.count)) * 0.15 }
        let withTotals = items.filter { ($0.total ?? 0) > 0 }.count
        if !items.isEmpty { score += (Double(withTotals) / Double(items.count)) * 0.15 }
        if total > 0 { score += 0.05 }
        return max(0, min(1, score))
    }
}
