//
//  InvoiceScannerService.swift
//  AutoCore
//
//  OCR накладных через VisionKit (VNRecognizeTextRequest).
//

import Foundation
import UIKit
import Vision

#if os(iOS)

final class InvoiceScannerService {
    
    /// Сканирует изображение и возвращает распознанную накладную (строки с name, quantity, price).
    func scanImage(image: UIImage) async -> ScannedInvoice {
        guard let cgImage = image.cgImage else {
            return ScannedInvoice(items: [], rawText: nil)
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            // Handled in results
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ru-RU", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            return ScannedInvoice(items: [], rawText: nil)
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return ScannedInvoice(items: [], rawText: nil)
        }
        
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let rawText = lines.joined(separator: "\n")
        let items = parseInvoiceLines(lines)
        
        return ScannedInvoice(
            scannedAt: Date(),
            items: items,
            rawText: rawText.isEmpty ? nil : rawText
        )
    }
    
    /// Парсит строки OCR: извлекает name, quantity, price.
    /// Ожидаемые форматы: "Название 2 150.00" или "Название 2 x 150" или "Название 150" и т.п.
    private func parseInvoiceLines(_ lines: [String]) -> [InvoiceItem] {
        var result: [InvoiceItem] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            var numbers: [Decimal] = []
            var nameParts: [String] = []
            
            for part in parts {
                let cleaned = part.replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: "\u{00A0}", with: "")
                if let qty = Int(cleaned), qty >= 0, qty <= 999999 {
                    numbers.append(Decimal(qty))
                } else if let decimal = Decimal(string: cleaned), decimal >= 0 {
                    numbers.append(decimal)
                } else if part.lowercased() != "x" && part != "×" {
                    nameParts.append(part)
                }
            }
            
            let name = nameParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if name.isEmpty { continue }
            
            if numbers.count >= 2 {
                let last = numbers.last!
                let prev = numbers.dropLast().last!
                let quantity = prev <= 10000 ? prev : 1
                let price = last
                if price > 0 {
                    result.append(InvoiceItem(name: name, quantity: quantity, price: price))
                }
            } else if numbers.count == 1, numbers[0] > 0 {
                result.append(InvoiceItem(name: name, quantity: 1, price: numbers[0]))
            }
        }
        
        return result
    }
}

#endif
