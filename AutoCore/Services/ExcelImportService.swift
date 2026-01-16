import Foundation
import CoreXLSX

struct ImportSheetData: Hashable {
    let name: String
    let rows: [[String]]
}

final class ExcelImportService {
    func loadSheets(from url: URL) throws -> [ImportSheetData] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ImportError.invalidFile
        }
        let sharedStrings = try file.parseSharedStrings()
        let workbooks = try file.parseWorkbooks()

        var sheets: [ImportSheetData] = []
        for workbook in workbooks {
            let worksheetInfos = try file.parseWorksheetPathsAndNames(workbook: workbook)
            for (name, path) in worksheetInfos {
                let sheetName = name ?? "Лист \(sheets.count + 1)"
                let worksheet = try file.parseWorksheet(at: path)
                let rows = parseRows(from: worksheet, sharedStrings: sharedStrings)
                sheets.append(
                    ImportSheetData(
                        name: sheetName,
                        rows: rows
                    )
                )
            }
        }
        return sheets
    }

    private func parseRows(from worksheet: Worksheet, sharedStrings: SharedStrings?) -> [[String]] {
        let rows = worksheet.data?.rows ?? []
        return rows.map { row in
            let cells = row.cells
            let maxIndex = cells.compactMap { columnIndex(from: $0.reference) }.max() ?? 0
            var values = Array(repeating: "", count: maxIndex + 1)
            for cell in cells {
                guard let index = columnIndex(from: cell.reference) else { continue }
                let value = resolvedCellValue(cell, sharedStrings: sharedStrings)
                values[index] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return values
        }
    }

    private func resolvedCellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings {
            return cell.stringValue(sharedStrings)
                ?? cell.inlineString?.text
                ?? cell.value
                ?? ""
        }
        return cell.inlineString?.text ?? cell.value ?? ""
    }

    private func columnIndex(from reference: CellReference?) -> Int? {
        guard let reference else { return nil }
        let letters = reference.column.value
        var result = 0
        for scalar in letters.unicodeScalars {
            guard let value = scalar.asciiUppercaseLetterValue else { continue }
            result = result * 26 + value
        }
        // Excel хранит колонки в формате A, B, AA, поэтому переводим в индекс массива.
        return result > 0 ? result - 1 : nil
    }
}

private enum ImportError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Файл не является корректным .xlsx или не может быть открыт."
        }
    }
}


private extension UnicodeScalar {
    var asciiUppercaseLetterValue: Int? {
        guard ("A"..."Z").contains(String(self)) else { return nil }
        return Int(value - UnicodeScalar("A").value + 1)
    }
}
