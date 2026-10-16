import Foundation
import SwiftData

@MainActor
enum DemoSeeder {
    /// Creates editable demonstration medicine data and honest historical records once.
    /// Sample adherence is recomputed from these records; no fixed percentage is displayed.
    static func seedIfNeeded(context: ModelContext) throws {
        if try !context.fetch(FetchDescriptor<Medicine>()).isEmpty { return }
        guard !UserDefaults.standard.bool(forKey: "medimate.demo.seeded.v1") else { return }
        let dayZero = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .day, value: -6, to: dayZero) ?? dayZero
        let fixture: [(name: String, type: String, initial: Int, threshold: Int, minutes: [Int])] = [
            ("Medicine A", "Tablet", 24, 16, [8 * 60, 13 * 60]),
            ("Medicine B", "Capsule", 30, 5, [10 * 60]),
            ("Medicine C", "Tablet", 20, 4, [20 * 60])
        ]
        var medicines: [Medicine] = []
        var plans: [MedicineSchedule] = []
        for (index, entry) in fixture.enumerated() {
            let medicine = Medicine(name: entry.name, type: entry.type,
                                    dosage: "1 \(entry.type.lowercased())",
                                    instructions: "Follow the directions on your prescription label.",
                                    startDate: start, initialStock: entry.initial, stock: entry.initial,
                                    refillThreshold: entry.threshold, isActive: true, sortOrder: index, isDemo: true)
            context.insert(medicine); medicines.append(medicine)
            for minutes in entry.minutes {
                let schedule = MedicineSchedule(medicineID: medicine.id, hour: minutes / 60, minute: minutes % 60, validFrom: start)
                context.insert(schedule); plans.append(schedule)
            }
        }
        context.insert(UserProfile())
        context.insert(AppSettings())
        try context.save()
        for daysAgo in (1...5).reversed() {
            guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: dayZero) else { continue }
            for (index, occurrence) in MedicationEngine.due(on: date, medicines: medicines, schedules: plans).enumerated() {
                // Introduce a modest variety of real sample actions; missed is a derived state.
                if (index + daysAgo) % 7 == 0 { continue }
                let status = (index + daysAgo) % 9 == 0 ? "skipped" : "taken"
                if let medicine = medicines.first(where: { $0.id == occurrence.medicineID }) {
                    try DoseService.record(status, occurrence: occurrence, medicine: medicine, context: context,
                                           now: occurrence.date.addingTimeInterval(180))
                }
            }
        }
        try context.save()
        UserDefaults.standard.set(true, forKey: "medimate.demo.seeded.v1")
    }
}
