import Foundation

/// A concrete scheduled dose, uniquely identified by schedule ID and local civil date.
struct DoseOccurrence: Identifiable, Hashable {
    var id: String
    var medicineID: UUID
    var name: String
    var dosage: String
    var date: Date
    var units: Int
    var scheduleID: UUID
}

enum MedicationEngine {
    static func occurrenceID(scheduleID: UUID, date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(scheduleID.uuidString)|\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static func due(on day: Date, medicine: Medicine, schedules: [MedicineSchedule],
                    calendar: Calendar = .current) -> [DoseOccurrence] {
        guard medicine.isActive else { return [] }
        let date = calendar.startOfDay(for: day)
        guard date >= calendar.startOfDay(for: medicine.startDate) else { return [] }
        if let end = medicine.endDate, date > calendar.startOfDay(for: end) { return [] }
        let weekday = calendar.component(.weekday, from: date)
        return schedules.filter { $0.medicineID == medicine.id && ($0.weekdays.isEmpty || $0.weekdays.contains(weekday)) }
            .compactMap { schedule in
                guard let moment = calendar.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: date),
                      moment >= schedule.validFrom else { return nil }
                return DoseOccurrence(id: occurrenceID(scheduleID: schedule.id, date: date, calendar: calendar),
                                      medicineID: medicine.id, name: medicine.name, dosage: medicine.dosage,
                                      date: moment, units: medicine.unitsPerDose, scheduleID: schedule.id)
            }.sorted { $0.date < $1.date }
    }

    static func due(on day: Date, medicines: [Medicine], schedules: [MedicineSchedule], calendar: Calendar = .current) -> [DoseOccurrence] {
        medicines.flatMap { due(on: day, medicine: $0, schedules: schedules, calendar: calendar) }
            .sorted { $0.date < $1.date }
    }

    static func range(start: Date, days: Int, medicines: [Medicine], schedules: [MedicineSchedule], calendar: Calendar = .current) -> [DoseOccurrence] {
        (0..<max(0, days)).flatMap { offset -> [DoseOccurrence] in
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start)) else { return [] }
            return due(on: date, medicines: medicines, schedules: schedules, calendar: calendar)
        }
    }

    static func status(for occurrence: DoseOccurrence, logs: [DoseLog], now: Date = .now) -> String {
        if let record = logs.first(where: { $0.occurrenceID == occurrence.id }) { return record.status }
        return occurrence.date < now ? "missed" : "upcoming"
    }

    static func adherence(occurrences: [DoseOccurrence], logs: [DoseLog], now: Date = .now) -> Double {
        let due = occurrences.filter { $0.date <= now }
        guard !due.isEmpty else { return 0 }
        let taken = due.filter { occurrence in logs.contains { $0.occurrenceID == occurrence.id && $0.status == "taken" } }.count
        return Double(taken) / Double(due.count)
    }

    static func streak(occurrences: [DoseOccurrence], logs: [DoseLog], now: Date = .now, calendar: Calendar = .current) -> Int {
        let eligible = occurrences.filter { $0.date <= now }
        let days = Dictionary(grouping: eligible) { calendar.startOfDay(for: $0.date) }
        var streak = 0
        for day in days.keys.sorted(by: >) {
            guard let doses = days[day], !doses.isEmpty else { continue }
            if doses.allSatisfy({ occ in logs.contains(where: { $0.occurrenceID == occ.id && $0.status == "taken" }) }) { streak += 1 }
            else { break }
        }
        return streak
    }

    static func suggestedSchedule(frequency: String, times: [Date], weekdays: [Int], intervalHours: Int,
                                  calendar: Calendar = .current) -> [(hour: Int, minute: Int, weekdays: [Int])] {
        let minutes: [Int]
        if frequency == "Every X hours" {
            let base = times.first ?? calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
            let start = calendar.component(.hour, from: base) * 60 + calendar.component(.minute, from: base)
            minutes = stride(from: start, through: 1439, by: max(1, intervalHours) * 60).map { $0 }
        } else {
            minutes = times.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
        }
        return Array(Set(minutes)).sorted().map { value in
            (hour: value / 60, minute: value % 60, weekdays: frequency == "Specific days" ? weekdays.sorted() : [])
        }
    }
}
