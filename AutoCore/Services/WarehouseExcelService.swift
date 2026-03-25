import Foundation
import ZIPFoundation

#if os(macOS)

final class WarehouseExcelService {
    func export(items: [InventoryItemEntity], to url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        let archive = try Archive(url: url, accessMode: .create)
        let rows = buildRows(items: items)

        try addEntry("xl/workbook.xml", data: workbookXML(), to: archive)
        try addEntry("_rels/.rels", data: rootRelsXML(), to: archive)
        try addEntry("xl/_rels/workbook.xml.rels", data: workbookRelsXML(), to: archive)
        try addEntry("[Content_Types].xml", data: contentTypesXML(), to: archive)
        try addEntry("xl/worksheets/sheet1.xml", data: worksheetXML(rows: rows), to: archive)
    }

    func importItems(from url: URL, companyId: String) throws -> [WarehouseItemInput] {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw NSError(domain: "WarehouseExcelService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть XLSX"])
        }

        let sharedStrings = try readSharedStrings(from: archive)
        let sheetPath = "xl/worksheets/sheet1.xml"
        guard let sheetData = try readData(path: sheetPath, from: archive),
              let sheetXML = String(data: sheetData, encoding: .utf8) else {
            throw NSError(domain: "WarehouseExcelService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Не найден sheet1.xml в XLSX"])
        }

        let rows = parseRows(from: sheetXML, sharedStrings: sharedStrings)
        guard rows.count > 1 else { return [] }

        return rows.dropFirst().compactMap { row in
            guard row.count >= 6 else { return nil }
            let quantity = Decimal(string: row[3].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let buyPrice = Decimal(string: row[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let sellPrice = Decimal(string: row[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            return WarehouseItemInput(
                name: row[0].trimmingCharacters(in: .whitespacesAndNewlines),
                partNumber: row[1].trimmingCharacters(in: .whitespacesAndNewlines),
                category: row[2].trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                buyPrice: buyPrice,
                sellPrice: sellPrice
            )
        }.filter { !$0.name.isEmpty && !$0.partNumber.isEmpty }
    }

    private func buildRows(items: [InventoryItemEntity]) -> [[String]] {
        let header = ["name", "partNumber", "category", "quantity", "buyPrice", "sellPrice"]
        let body = items.map { item in
            [
                item.name,
                item.partNumber,
                item.category,
                "\(item.quantity)",
                "\(item.buyPrice)",
                "\(item.sellPrice)"
            ]
        }
        return [header] + body
    }

    private func workbookXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="СКЛАД" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """.utf8)
    }

    private func rootRelsXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """.utf8)
    }

    private func workbookRelsXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """.utf8)
    }

    private func contentTypesXML() -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
        """.utf8)
    }

    private func worksheetXML(rows: [[String]]) -> Data {
        let rowXML = rows.enumerated().map { rowIndex, row in
            let cellXML = row.enumerated().map { colIndex, value in
                let ref = "\(columnLetter(for: colIndex))\(rowIndex + 1)"
                return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(escapeXML(value))</t></is></c>"
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cellXML)</row>"
        }.joined()

        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>\(rowXML)</sheetData>
        </worksheet>
        """.utf8)
    }

    private func columnLetter(for index: Int) -> String {
        var index = index
        var letters = ""
        repeat {
            let remainder = index % 26
            letters = String(UnicodeScalar(remainder + 65)!) + letters
            index = index / 26 - 1
        } while index >= 0
        return letters
    }

    private func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func unescapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func addEntry(_ path: String, data: Data, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            data.subdata(in: Int(position)..<Int(position) + size)
        }
    }

    private func readData(path: String, from archive: Archive) throws -> Data? {
        guard let entry = archive[path] else { return nil }
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    private func readSharedStrings(from archive: Archive) throws -> [String] {
        guard let data = try readData(path: "xl/sharedStrings.xml", from: archive),
              let xml = String(data: data, encoding: .utf8) else {
            return []
        }
        let pattern = "<si[^>]*>(.*?)</si>"
        let entries = matches(in: xml, pattern: pattern)
        return entries.map { entry in
            let t = firstMatch(in: entry, pattern: "<t[^>]*>(.*?)</t>") ?? ""
            return unescapeXML(t)
        }
    }

    private func parseRows(from xml: String, sharedStrings: [String]) -> [[String]] {
        let rowMatches = matches(in: xml, pattern: "<row[^>]*>(.*?)</row>")
        return rowMatches.map { rowContent in
            let cells = matchesWithGroups(in: rowContent, pattern: "<c[^>]*?(?:t=\"([^\"]+)\")?[^>]*>(.*?)</c>")
            return cells.map { groups in
                let type = groups.count > 1 ? groups[1] : ""
                let body = groups.count > 2 ? groups[2] : ""
                if type == "inlineStr" {
                    let text = firstMatch(in: body, pattern: "<t[^>]*>(.*?)</t>") ?? ""
                    return unescapeXML(text)
                }
                let rawValue = firstMatch(in: body, pattern: "<v[^>]*>(.*?)</v>") ?? ""
                if type == "s", let index = Int(rawValue), index < sharedStrings.count {
                    return sharedStrings[index]
                }
                return unescapeXML(rawValue)
            }
        }
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    private func matchesWithGroups(in text: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { match in
            (0..<match.numberOfRanges).map { idx in
                let range = match.range(at: idx)
                guard range.location != NSNotFound else { return "" }
                return nsText.substring(with: range)
            }
        }
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        matches(in: text, pattern: pattern).first
    }
}

#endif
