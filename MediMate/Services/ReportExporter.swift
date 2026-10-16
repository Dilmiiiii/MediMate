import Foundation

@MainActor
enum ReportExporter {
    static func csv(logs: [DoseLog]) -> URL? {
        let header = "Medicine,Scheduled,Responded,Status,Stock Deducted\n"
        let formatter = ISO8601DateFormatter()
        let records = logs.sorted { $0.scheduledAt > $1.scheduledAt }.map {
            "\"\($0.nameSnapshot.replacingOccurrences(of: "\"", with: "\"\""))\",\(formatter.string(from: $0.scheduledAt)),\(formatter.string(from: $0.respondedAt)),\($0.status),\($0.stockDeducted)"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MediMate-History.csv")
        do { try (header + records.joined(separator: "\n")).write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }
}
