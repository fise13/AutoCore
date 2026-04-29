import Foundation

/// Только HTTP API (OpenRouter / OpenAI-совместимый) — без Vision и без «скана».
/// Сопоставляет листы Excel с каталогом брендов/двигателей и ролями колонок (в т.ч. «Проданные»).
final class ImportOpenRouterMappingService {

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        struct ResponseFormat: Encodable { let type: String }
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
        let response_format: ResponseFormat
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg
        }
        let choices: [Choice]
    }

    private let session: URLSession
    private let baseURL: URL
    private let model: String
    private let apiKey: String
    private let maxTokens: Int

    init(session: URLSession = .shared) {
        self.session = session
        let env = ProcessInfo.processInfo.environment
        let base = env["OPENROUTER_BASE_URL"] ?? "https://openrouter.ai/api/v1"
        self.baseURL = URL(string: base) ?? URL(string: "https://openrouter.ai/api/v1")!
        self.model   = env["OPENROUTER_MODEL"]   ?? "openai/gpt-4o-mini"
        self.apiKey  = OpenRouterKeyProvider.resolved
        self.maxTokens = Int(env["OPENROUTER_MAX_TOKENS"] ?? "") ?? 1200
    }

    /// Результат: решение по каждому листу + опциональные роли колонок (0-based index → role).
    func resolve(
        sheetPayloads: [ImportSheetAIPayload],
        brands: [Brand],
        engines: [Engine],
        brandNameById: [Int64: String]
    ) async throws -> ImportAIResolution {
        guard !apiKey.isEmpty else {
            throw ImportAIError.missingAPIKey
        }

        let catalogText = buildCatalogText(brands: brands, engines: engines, brandNameById: brandNameById)
        do {
            return try await resolveOnce(sheetPayloads: sheetPayloads, catalogText: catalogText)
        } catch let err as ImportAIError {
            // Частый случай: ответ обрезан по токенам и JSON ломается в конце.
            switch err {
            case .decodeSchema, .emptyModelContent, .decodeChat:
                return try await resolveInBatches(sheetPayloads: sheetPayloads, catalogText: catalogText)
            default:
                throw err
            }
        } catch {
            throw error
        }
    }

    private func resolveOnce(
        sheetPayloads: [ImportSheetAIPayload],
        catalogText: String
    ) async throws -> ImportAIResolution {
        let sheetsText  = buildSheetsText(sheetPayloads)

        let system = """
        Ты помогаешь импорту склада моторов AutoCore из Excel. Цель — чтобы каждая строка мапилась в ту же схему, что и ручной импорт: мотор = двигатель из каталога + серийник + даты.

        Для КАЖДОГО листа выбери import_type:
        - "engines" — склад/учёт моторов: бренд, код двигателя, в строках — серийники, приход, продажа и т.д.
        - "specific" — не основной склад: ремонт, заметки, вспомогательные таблицы (укажи category_name).
        - "skip" — мусор, своды без строк моторов, пусто.

        Листы «Проданные», «Продажи», sales, sold — это тоже "engines", если в строках есть серийник и дата/сумма продажи. Обязательно: column_roles с serial_code и sold_date. Цену/сумму мапь в notes или ignore (не в sold_date).
        Листы только с приходом/остатком без продажи — тоже "engines" с arrival_date, если дата прихода есть.

        Сопоставление с каталогом:
        - Сначала ищи точное или почти совпадение кода двигателя (без разницы в регистре, пробелы/дефисы не важны) среди «Двигатели (пример)».
        - brand_name возьми из той же строки бренда, что и выбранный engine в каталоге. Если в таблице один бренд/модель на весь лист — один brand_name + engine_code на весь лист.
        - Если в каталоге нет кода, но в листе он явно указан (заголовок, первая колонка) — укажи нормализованный engine_code (например EJ253) и бренд как в файле; импорт создаст отсутствующие сущности.

        column_roles: ключ — индекс колонки с 0, значение одно из:
        serial_code, configuration, notes, quantity, transmission, arrival_date, sold_date, ignore.
        Не оставляй пустой column_roles на листе "engines" — нужен хотя бы serial_code плюс одна дата, если даты есть.

        Дополнительно:
        - confidence: число 0...1 по уверенности именно в sheet-level решении.
        - detected_sold_sheet: true, если это лист проданных/продаж или строки явно про проданные моторы.
        - fallback_date_columns: список индексов колонок (0-based), которые можно использовать как sold_date если основной sold_date пуст.
          Ставь в порядке приоритета (лучший кандидат первым).

        Верни ТОЛЬКО JSON по схеме из запроса пользователя.
        """

        let user = """
        Каталог (фрагмент):
        \(catalogText)

        Листы Excel (имя + пример строк):
        \(sheetsText)

        JSON-схема ответа (строго):
        {
          "sheets": [
            {
              "sheet_name": "точное имя листа",
              "import_type": "engines" | "specific" | "skip",
              "brand_name": "строка или null",
              "engine_code": "нормализованный код вроде EJ253 или null",
              "category_name": "для specific или null",
              "column_roles": { "0": "serial_code", "1": "sold_date" },
              "confidence": 0.0,
              "detected_sold_sheet": false,
              "fallback_date_columns": [1, 3]
            }
          ],
          "notes": "кратко по-русски"
        }
        """

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.15,
            max_tokens: max(256, min(maxTokens, 4096)),
            response_format: .init(type: "json_object")
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let u = error as? URLError {
                throw ImportAIError.network(underlying: u)
            }
            throw ImportAIError.requestFailed(underlyingDescription: error.localizedDescription)
        }
        let endpoint = request.url?.absoluteString ?? "chat/completions"
        guard let http = response as? HTTPURLResponse else {
            let raw = dataSnippet(data)
            throw ImportAIError.unexpectedResponse(type: "не HTTP", bodySnippet: raw)
        }
        if !(200...299).contains(http.statusCode) {
            let body = dataSnippet(data, max: 2_000)
            throw ImportAIError.http(
                status: http.statusCode,
                model: model,
                endpoint: endpoint,
                bodySnippet: body
            )
        }
        let chat: ChatResponse
        do {
            chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            let raw = dataSnippet(data, max: 1_500)
            throw ImportAIError.decodeChat(
                model: model,
                endpoint: endpoint,
                decodeError: error.localizedDescription,
                bodySnippet: raw
            )
        }
        let content = chat.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = sanitizeJSON(content)
        guard let json = cleaned.data(using: .utf8) else {
            throw ImportAIError.emptyModelContent
        }
        do {
            return try JSONDecoder().decode(ImportAIResolution.self, from: json)
        } catch {
            let raw = String(cleaned.prefix(1_200))
            throw ImportAIError.decodeSchema(
                model: model,
                decodeError: error.localizedDescription,
                contentSnippet: raw
            )
        }
    }

    private func resolveInBatches(
        sheetPayloads: [ImportSheetAIPayload],
        catalogText: String
    ) async throws -> ImportAIResolution {
        guard !sheetPayloads.isEmpty else {
            return ImportAIResolution(sheets: [], notes: "AI: пустой набор листов.")
        }
        let batchSize = 5
        var all: [ImportAIResolution.SheetDecision] = []
        var notes: [String] = []

        for chunk in sheetPayloads.chunked(into: batchSize) {
            let part = try await resolveOnce(sheetPayloads: chunk, catalogText: catalogText)
            all.append(contentsOf: part.sheets)
            if let n = part.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                notes.append(n)
            }
        }

        return ImportAIResolution(
            sheets: all,
            notes: notes.isEmpty ? "AI: сопоставление выполнено батчами." : notes.joined(separator: "\n")
        )
    }

    private func dataSnippet(_ data: Data, max: Int = 1_200) -> String {
        if let t = String(data: data, encoding: .utf8) {
            return t.count <= max ? t : String(t.prefix(max)) + "… (обрезано)"
        }
        return "бинарные данные, \(data.count) байт"
    }

    private func buildCatalogText(brands: [Brand], engines: [Engine], brandNameById: [Int64: String]) -> String {
        let brandLines = brands.map { "id=\($0.id) name=\($0.name)" }.joined(separator: "\n")
        let engSample = engines.prefix(120).map { e -> String in
            let b = brandNameById[e.brandID] ?? "?"
            return "engine id=\(e.id) brand=\(b) code=\(e.code)"
        }.joined(separator: "\n")
        return "Бренды:\n\(brandLines)\n\nДвигатели (пример):\n\(engSample)"
    }

    private func buildSheetsText(_ sheets: [ImportSheetAIPayload]) -> String {
        sheets.map { s in
            let rows = s.sampleRows.map { r in
                r.prefix(16).joined(separator: " | ")
            }.joined(separator: "\n   ")
            return "— \(s.name) (строк ~\(s.rowCount)):\n   \(rows)"
        }.joined(separator: "\n\n")
    }

    private func sanitizeJSON(_ text: String) -> String {
        var s = text
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
            s = s.replacingOccurrences(of: "```", with: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - API models

struct ImportSheetAIPayload: Encodable {
    let name: String
    let rowCount: Int
    /// Первые несколько строк (усечённых) для контекста
    let sampleRows: [[String]]
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var out: [[Element]] = []
        out.reserveCapacity((count + size - 1) / size)
        var i = 0
        while i < count {
            let j = Swift.min(i + size, count)
            out.append(Array(self[i..<j]))
            i = j
        }
        return out
    }
}

struct ImportAIResolution: Decodable {
    struct SheetDecision: Decodable {
        let sheet_name: String
        let import_type: String
        let brand_name: String?
        let engine_code: String?
        let category_name: String?
        let column_roles: [String: String]?
        let confidence: Double?
        let detected_sold_sheet: Bool?
        let fallback_date_columns: [Int]?
    }
    let sheets: [SheetDecision]
    let notes: String?
}

enum ImportAIError: LocalizedError {
    case missingAPIKey
    /// HTTP ≠ 2xx: тело OpenRouter/прокси часто содержит `error.message`.
    case http(status: Int, model: String, endpoint: String, bodySnippet: String)
    case network(underlying: URLError)
    case requestFailed(underlyingDescription: String)
    case unexpectedResponse(type: String, bodySnippet: String)
    case decodeChat(model: String, endpoint: String, decodeError: String, bodySnippet: String)
    case emptyModelContent
    case decodeSchema(model: String, decodeError: String, contentSnippet: String)

    var errorDescription: String? { detailed }

    var failureReason: String? {
        switch self {
        case .missingAPIKey: return "Ключ не задан"
        case .http(let s, _, _, _): return "HTTP \(s)"
        case .network: return "Сеть (URLSession)"
        case .requestFailed: return "Ошибка запроса"
        case .unexpectedResponse: return "Формат ответа"
        case .decodeChat: return "JSON ответа чата"
        case .emptyModelContent: return "Пустой content у модели"
        case .decodeSchema: return "JSON схемы сопоставления"
        }
    }

    var recoverySuggestion: String? {
        "Проверьте ключ OpenRouter, баланс, лимит и модель (OPENROUTER_MODEL). URL: " +
        (ProcessInfo.processInfo.environment["OPENROUTER_BASE_URL"] ?? "https://openrouter.ai/api/v1")
    }

    private var detailed: String {
        switch self {
        case .missingAPIKey:
            return """
            Не задан API-ключ. Задайте OPENROUTER_API_KEY или OPENAI_API_KEY (среда Xcode, либо \
            `defaults write fise.AutoCore OPENROUTER_API_KEY '…'` и перезапустите приложение).
            """
        case .http(let status, let model, let endpoint, let body):
            return """
            Запрос к модели «\(model)» завершился с HTTP \(status).
            Эндпоинт: \(endpoint)

            Тело ответа (первый фрагмент):
            \(body)

            Подсказка:
            - Снизьте токены ответа через OPENROUTER_MAX_TOKENS (сейчас \(ProcessInfo.processInfo.environment["OPENROUTER_MAX_TOKENS"] ?? "1200")).
            - Либо пополните кредиты: https://openrouter.ai/settings/credits
            """
        case .network(let u):
            return """
            Сетевая ошибка: \(u.localizedDescription) (код \(u.errorCode))
            Часто: нет интернета, тайм-аут, прокси, блокировка TLS или смена сети.
            """
        case .requestFailed(let s):
            return "Не удалось выполнить запрос: \(s)"
        case .unexpectedResponse(let t, let body):
            return "Неожиданный ответ: \(t)\n\n\(body)"
        case .decodeChat(_, _, let e, let body):
            return """
            Ответ 200, но JSON не соответствует ожидаемой форме чата. Ошибка декодера: \(e)

            Сырой фрагмент:
            \(body)
            """
        case .emptyModelContent:
            return "В ответе нет `choices[0].message.content` (пусто после разбора)."
        case .decodeSchema(_, let e, let raw):
            return """
            JSON от модели не удалось привести к схеме сопоставления. Ошибка: \(e)

            Содержимое (первые символы):
            \(raw)
            """
        }
    }
}
