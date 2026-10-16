import XCTest
import SwiftData
@testable import MediMate

@MainActor
final class MediMateEngineTests: XCTestCase {
    private func memoryContext() throws -> ModelContext {
        let schema = Schema([Medicine.self, MedicineSchedule.self, DoseLog.self,
                             StockEvent.self, UserProfile.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config]).mainContext
    }

    func testWeekdayRecurrenceAndDateRange() {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 12))!
        let med = Medicine(name: "Example", startDate: day)
        let schedule = MedicineSchedule(medicineID: med.id, hour: 8, weekdays: [2], validFrom: cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!)
        XCTAssertEqual(MedicationEngine.due(on: day, medicine: med, schedules: [schedule], calendar: cal).count, 1)
        let next = cal.date(byAdding: .day, value: 1, to: day)!
        XCTAssertEqual(MedicationEngine.due(on: next, medicine: med, schedules: [schedule], calendar: cal).count, 0)
        med.endDate = day
        XCTAssertEqual(MedicationEngine.due(on: next, medicine: med, schedules: [schedule], calendar: cal).count, 0)
    }

    func testEveryXHoursProducesDistinctValidSlots() {
        let clock = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: .now)!
        let slots = MedicationEngine.suggestedSchedule(frequency: "Every X hours", times: [clock], weekdays: [], intervalHours: 6)
        XCTAssertEqual(slots.map(\.hour), [7, 13, 19])
        XCTAssertTrue(slots.allSatisfy { $0.minute == 30 })
    }

    func testRecordTakenOnlyOnceAndCorrectionRestoresStock() throws {
        let context = try memoryContext()
        let medicine = Medicine(name: "Test", stock: 10, unitsPerDose: 2)
        let schedule = MedicineSchedule(medicineID: medicine.id, hour: 8, validFrom: Calendar.current.startOfDay(for: .now))
        context.insert(medicine); context.insert(schedule)
        let occurrence = MedicationEngine.due(on: .now, medicine: medicine, schedules: [schedule]).first!
        XCTAssertTrue(try DoseService.record("taken", occurrence: occurrence, medicine: medicine, context: context))
        XCTAssertEqual(medicine.stock, 8)
        XCTAssertFalse(try DoseService.record("taken", occurrence: occurrence, medicine: medicine, context: context))
        XCTAssertEqual(medicine.stock, 8)
        XCTAssertTrue(try DoseService.record("skipped", occurrence: occurrence, medicine: medicine, context: context))
        XCTAssertEqual(medicine.stock, 10)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DoseLog>()).count, 1)
    }

    func testRestockingIsPersistedAsInventoryEvent() throws {
        let context = try memoryContext()
        let medicine = Medicine(name: "Sample", stock: 3)
        context.insert(medicine)
        try DoseService.restock(7, medicine: medicine, context: context)
        XCTAssertEqual(medicine.stock, 10)
        let events = try context.fetch(FetchDescriptor<StockEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].change, 7)
    }

    func testAdherenceExcludesUpcomingDoses() {
        let med = Medicine(name: "Sample")
        let before = DoseOccurrence(id: "due", medicineID: med.id, name: med.name,
                                    dosage: "1", date: .now.addingTimeInterval(-600), units: 1, scheduleID: UUID())
        let after = DoseOccurrence(id: "future", medicineID: med.id, name: med.name,
                                   dosage: "1", date: .now.addingTimeInterval(600), units: 1, scheduleID: UUID())
        let log = DoseLog(occurrenceID: "due", medicineID: med.id, nameSnapshot: med.name,
                          scheduledAt: before.date, status: "taken")
        XCTAssertEqual(MedicationEngine.adherence(occurrences: [before, after], logs: [log]), 1.0, accuracy: 0.0001)
    }

    func testOCRParsingNeedsRealInputText() {
        let result = OCRParser.parse("MEDICINE A\nStrength: 500 mg\nTake as instructed on prescription label\nEXP 2028-12-31")
        XCTAssertEqual(result.name, "MEDICINE A")
        XCTAssertEqual(result.strength, "500 mg")
        XCTAssertEqual(result.expiry, "2028-12-31")
        XCTAssertFalse(result.instructions.isEmpty)
    }

    func testMedicineFormValidatesPrescribedDoseAndSchedule() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let slots = [(hour: 8, minute: 0, weekdays: [Int]())]
        let invalid = MedicineFormViewModel.error(name: "", prescribedDosage: "1 tablet",
            frequency: "Daily", weekdays: [], startDate: day, endDate: nil,
            slots: slots, stock: 10, unitsPerDose: 1, threshold: 2)
        XCTAssertNotNil(invalid)
        let emptyDays = MedicineFormViewModel.error(name: "Prescription A", prescribedDosage: "1 tablet",
            frequency: "Specific days", weekdays: [], startDate: day, endDate: nil,
            slots: slots, stock: 10, unitsPerDose: 1, threshold: 2)
        XCTAssertNotNil(emptyDays)
        let valid = MedicineFormViewModel.error(name: "Prescription A", prescribedDosage: "1 tablet",
            frequency: "Daily", weekdays: [], startDate: day, endDate: nil,
            slots: slots, stock: 10, unitsPerDose: 1, threshold: 2)
        XCTAssertNil(valid)
    }

    func testNewScheduleDoesNotCreateHistoricalMissedDoses() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let med = Medicine(name: "New Medicine", startDate: today.addingTimeInterval(-7 * 86_400))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let schedule = MedicineSchedule(medicineID: med.id, hour: 8, validFrom: tomorrow)
        XCTAssertTrue(MedicationEngine.due(on: today, medicine: med, schedules: [schedule]).isEmpty)
        XCTAssertEqual(MedicationEngine.due(on: tomorrow, medicine: med, schedules: [schedule]).count, 1)
    }

    func testDoseOccurrenceIdentifiersAreDeterministic() {
        let id = UUID()
        let value = Date.now
        XCTAssertEqual(MedicationEngine.occurrenceID(scheduleID: id, date: value),
                       MedicationEngine.occurrenceID(scheduleID: id, date: value))
    }
}
