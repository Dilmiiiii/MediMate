import Foundation

/// Testable field-level validation shared by create and edit workflows.
enum MedicineFormViewModel {
    static func error(name: String, prescribedDosage: String, frequency: String,
                      weekdays: Set<Int>, startDate: Date, endDate: Date?,
                      slots: [(hour: Int, minute: Int, weekdays: [Int])],
                      stock: Int, unitsPerDose: Int, threshold: Int, calendar: Calendar = .current) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            prescribedDosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a medication name and the prescribed dosage."
        }
        if let endDate, calendar.startOfDay(for: endDate) < calendar.startOfDay(for: startDate) {
            return "The end date must not be before the start date."
        }
        if frequency == "Specific days" && weekdays.isEmpty {
            return "Check Reminder Time: select at least one weekday."
        }
        if slots.isEmpty { return "Check Reminder Time: please select a valid reminder schedule." }
        if stock < 0 || unitsPerDose <= 0 || threshold < 0 { return "Enter a valid, non-negative stock and dosage quantity." }
        return nil
    }
}
