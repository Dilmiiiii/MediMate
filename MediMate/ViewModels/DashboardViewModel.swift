import Foundation

/// Stateless presentation model; views observe SwiftData and ask this type to calculate live summaries.
@MainActor
enum DashboardViewModel {
    struct Summary {
        let doses: [DoseOccurrence]
        let taken: Int
        let next: DoseOccurrence?
        var progress: Double { doses.isEmpty ? 0 : Double(taken) / Double(doses.count) }
    }
    static func today(medicines: [Medicine], schedules: [MedicineSchedule], logs: [DoseLog], at date: Date = .now) -> Summary {
        let doses = MedicationEngine.due(on: date, medicines: medicines, schedules: schedules)
        let taken = doses.filter { MedicationEngine.status(for: $0, logs: logs, now: date) == "taken" }.count
        let next = doses.first { MedicationEngine.status(for: $0, logs: logs, now: date) == "upcoming" }
        return Summary(doses: doses, taken: taken, next: next)
    }
    static func lowStock(medicines: [Medicine]) -> [Medicine] {
        medicines.filter { $0.isActive && $0.stock <= $0.refillThreshold }
    }
}
