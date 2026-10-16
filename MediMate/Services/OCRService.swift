import Foundation
import Vision
import UIKit

struct ScannedMedicine: Hashable {
    var name: String = ""
    var strength: String = ""
    var instructions: String = ""
    var expiry: String = ""
    var rawText: String = ""
}

enum OCRParser {
    static func parse(_ text: String) -> ScannedMedicine {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let strength = firstMatch(#"\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml)\b"#, text: text)
        let expiry = firstMatch(#"\b(?:20\d{2})[-/]\d{1,2}[-/]\d{1,2}\b"#, text: text)
        let name = lines.first { line in
            let l = line.lowercased()
            return !l.hasPrefix("strength") && !l.hasPrefix("exp") && !l.hasPrefix("take ") && !l.hasPrefix("instructions")
        } ?? ""
        let instruction = lines.first { $0.lowercased().hasPrefix("take ") || $0.lowercased().hasPrefix("instructions") } ?? ""
        return ScannedMedicine(name: name, strength: strength, instructions: instruction, expiry: expiry, rawText: text)
    }

    private static func firstMatch(_ pattern: String, text: String) -> String {
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return "" }
        return String(text[range])
    }
}

enum OCRService {
    static func recognize(_ image: UIImage) async throws -> ScannedMedicine {
        guard let cgImage = image.cgImage else { throw NSError(domain: "MediMateOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read the selected image."]) }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    let handler = VNImageRequestHandler(cgImage: cgImage)
                    try handler.perform([request])
                    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    guard !lines.isEmpty else {
                        throw NSError(domain: "MediMateOCR", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to Read Label"])
                    }
                    continuation.resume(returning: OCRParser.parse(lines.joined(separator: "\n")))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
