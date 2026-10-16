import Foundation
import SwiftData

@Model
final class Medicine {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: String
    var dosage: String
    var strength: String
    var expiryDateText: String
    var instructions: String
    var frequency: String
    var intervalHours: Int
    var startDate: Date
    var endDate: Date?
    var initialStock: Int
    var stock: Int
    var unitsPerDose: Int
    var refillThreshold: Int
    var unit: String
    var photo: Data?
    var isActive: Bool
    var notificationsEnabled: Bool
    var sortOrder: Int
    var isDemo: Bool

    init(id: UUID = UUID(), name: String, type: String = "Tablet", dosage: String = "1 tablet",
         strength: String = "", expiryDateText: String = "", instructions: String = "", frequency: String = "Daily", intervalHours: Int = 8,
         startDate: Date = .now, endDate: Date? = nil, initialStock: Int = 20, stock: Int = 20,
         unitsPerDose: Int = 1, refillThreshold: Int = 5, unit: String = "tablets",
         photo: Data? = nil, isActive: Bool = true, notificationsEnabled: Bool = true,
         sortOrder: Int = 0, isDemo: Bool = false) {
        self.id = id; self.name = name; self.type = type; self.dosage = dosage
        self.strength = strength; self.expiryDateText = expiryDateText; self.instructions = instructions; self.frequency = frequency
        self.intervalHours = intervalHours; self.startDate = startDate; self.endDate = endDate
        self.initialStock = initialStock; self.stock = stock; self.unitsPerDose = unitsPerDose
        self.refillThreshold = refillThreshold; self.unit = unit; self.photo = photo
        self.isActive = isActive; self.notificationsEnabled = notificationsEnabled
        self.sortOrder = sortOrder; self.isDemo = isDemo
    }
}

@Model
final class MedicineSchedule {
    @Attribute(.unique) var id: UUID
    var medicineID: UUID
    var hour: Int
    var minute: Int
    // Calendar weekday integers (Sunday 1 ... Saturday 7). Empty means daily.
    var weekdays: [Int]
    var validFrom: Date
    init(id: UUID = UUID(), medicineID: UUID, hour: Int, minute: Int = 0, weekdays: [Int] = [], validFrom: Date = .now) {
        self.id = id; self.medicineID = medicineID
        self.hour = hour; self.minute = minute; self.weekdays = weekdays; self.validFrom = validFrom
    }
}

@Model
final class DoseLog {
    @Attribute(.unique) var occurrenceID: String
    var medicineID: UUID
    var nameSnapshot: String
    var scheduledAt: Date
    var respondedAt: Date
    // "taken" or "skipped". Missing/upcoming statuses are derived from time.
    var status: String
    var stockDeducted: Int
    init(occurrenceID: String, medicineID: UUID, nameSnapshot: String,
         scheduledAt: Date, respondedAt: Date = .now, status: String, stockDeducted: Int = 0) {
        self.occurrenceID = occurrenceID; self.medicineID = medicineID
        self.nameSnapshot = nameSnapshot; self.scheduledAt = scheduledAt
        self.respondedAt = respondedAt; self.status = status; self.stockDeducted = stockDeducted
    }
}

@Model
final class StockEvent {
    @Attribute(.unique) var id: UUID
    var medicineID: UUID
    var nameSnapshot: String
    var change: Int
    var reason: String
    var occurrenceID: String?
    var createdAt: Date
    init(medicineID: UUID, nameSnapshot: String, change: Int, reason: String,
         occurrenceID: String? = nil, createdAt: Date = .now) {
        self.id = UUID(); self.medicineID = medicineID; self.nameSnapshot = nameSnapshot
        self.change = change; self.reason = reason; self.occurrenceID = occurrenceID
        self.createdAt = createdAt
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var fullName: String
    var birthday: Date
    var emergencyName: String
    var emergencyPhone: String
    var allergies: String
    var medicalNotes: String
    init(fullName: String = "Alex Morgan", birthday: Date = Calendar.current.date(from: DateComponents(year: 2000, month: 6, day: 12)) ?? .now,
         emergencyName: String = "", emergencyPhone: String = "", allergies: String = "", medicalNotes: String = "") {
        self.id = UUID(); self.fullName = fullName; self.birthday = birthday
        self.emergencyName = emergencyName; self.emergencyPhone = emergencyPhone
        self.allergies = allergies; self.medicalNotes = medicalNotes
    }
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var medicationReminders: Bool
    var refillAlerts: Bool
    var appearance: String
    var largerText: Bool
    var language: String
    var snoozeMinutes: Int
    init(medicationReminders: Bool = true, refillAlerts: Bool = true,
         appearance: String = "System Default", largerText: Bool = false,
         language: String = "English", snoozeMinutes: Int = 15) {
        self.id = UUID(); self.medicationReminders = medicationReminders
        self.refillAlerts = refillAlerts; self.appearance = appearance
        self.largerText = largerText; self.language = language
        self.snoozeMinutes = snoozeMinutes
    }
}
