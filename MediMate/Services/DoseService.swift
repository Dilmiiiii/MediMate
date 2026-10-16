import Foundation
import SwiftData

@MainActor
enum DoseService {
    /// Applies each change exactly once. Updating a Taken record restores its exact previous deduction.
    @discardableResult
    static func record(_ status: String, occurrence: DoseOccurrence, medicine: Medicine, context: ModelContext,
                       now: Date = .now) throws -> Bool {
        guard status == "taken" || status == "skipped" else { return false }
        let id = occurrence.id
        let existing = try context.fetch(FetchDescriptor<DoseLog>(predicate: #Predicate { $0.occurrenceID == id })).first
        if existing?.status == status { return false }
        if let existing, existing.stockDeducted > 0 {
            medicine.stock += existing.stockDeducted
            context.insert(StockEvent(medicineID: medicine.id, nameSnapshot: medicine.name,
                                      change: existing.stockDeducted, reason: "Dose correction", occurrenceID: id))
            existing.stockDeducted = 0
        }
        let deduction = status == "taken" ? min(max(0, medicine.stock), max(0, medicine.unitsPerDose)) : 0
        if deduction > 0 {
            medicine.stock -= deduction
            context.insert(StockEvent(medicineID: medicine.id, nameSnapshot: medicine.name,
                                      change: -deduction, reason: "Confirmed dose", occurrenceID: id))
        }
        if let existing {
            existing.status = status; existing.respondedAt = now; existing.stockDeducted = deduction
        } else {
            context.insert(DoseLog(occurrenceID: id, medicineID: medicine.id, nameSnapshot: medicine.name,
                                   scheduledAt: occurrence.date, respondedAt: now, status: status, stockDeducted: deduction))
        }
        try context.save()
        return true
    }

    static func restock(_ quantity: Int, medicine: Medicine, context: ModelContext) throws {
        guard quantity > 0 else { return }
        medicine.stock += quantity
        context.insert(StockEvent(medicineID: medicine.id, nameSnapshot: medicine.name,
                                  change: quantity, reason: "Purchased stock"))
        try context.save()
    }
}
