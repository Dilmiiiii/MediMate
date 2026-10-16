import Foundation
import SwiftData
import UserNotifications

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()
    private var container: ModelContainer?
    private override init() { super.init() }

    @MainActor func configure(container: ModelContainer) {
        self.container = container
        let taken = UNNotificationAction(identifier: "DOSE_TAKEN", title: "Taken", options: [])
        let snooze = UNNotificationAction(identifier: "DOSE_SNOOZE", title: "Remind Later", options: [])
        let skip = UNNotificationAction(identifier: "DOSE_SKIP", title: "Skip", options: [])
        let category = UNNotificationCategory(identifier: "MEDIMATEGROUP", actions: [taken, snooze, skip], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    @MainActor func refresh(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let old = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: old.map(\.identifier).filter { $0.hasPrefix("medimate|dose|") })
        guard let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
              settings.medicationReminders else {
            await clearAppReminders()
            return
        }
        guard let meds = try? context.fetch(FetchDescriptor<Medicine>()),
              let plans = try? context.fetch(FetchDescriptor<MedicineSchedule>()),
              let logs = try? context.fetch(FetchDescriptor<DoseLog>()) else { return }
        let today = Calendar.current.startOfDay(for: .now)
        let now = Date.now
        let upcoming = MedicationEngine.range(start: today, days: 14, medicines: meds, schedules: plans)
            .filter { item in
                item.date > now && (meds.first(where: { $0.id == item.medicineID })?.notificationsEnabled ?? false)
                && !logs.contains(where: { $0.occurrenceID == item.id })
            }.prefix(48)
        // Keep valid snoozes, but cancel ones whose occurrence was already recorded.
        let alreadyLogged = Set(logs.map(\.occurrenceID))
        let knownMedicineIDs = Set(meds.map { $0.id.uuidString })
        let obsoleteSnoozes = old.filter { request in
            guard request.identifier.hasPrefix("medimate|snooze|") else { return false }
            let occurrenceID = String(request.identifier.dropFirst("medimate|snooze|".count))
            let oldMedicineID = request.content.userInfo["medicineID"] as? String ?? ""
            return alreadyLogged.contains(occurrenceID) || !knownMedicineIDs.contains(oldMedicineID)
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: obsoleteSnoozes)
        for occurrence in upcoming {
            let content = UNMutableNotificationContent()
            content.title = "Time for Your Medicine!"
            content.body = "\(occurrence.name) – \(occurrence.dosage). It's time for your scheduled dose."
            content.sound = .default
            content.categoryIdentifier = "MEDIMATEGROUP"
            content.userInfo = ["occurrenceID": occurrence.id, "medicineID": occurrence.medicineID.uuidString,
                                "scheduledAt": occurrence.date.timeIntervalSince1970, "scheduleID": occurrence.scheduleID.uuidString]
            let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: occurrence.date)
            let request = UNNotificationRequest(identifier: "medimate|dose|\(occurrence.id)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    @MainActor func clearAppReminders() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier)
            .filter { $0.hasPrefix("medimate|") })
    }

    @MainActor func snooze(info: [AnyHashable: Any], minutes: Int) async {
        guard let occurrenceID = info["occurrenceID"] as? String else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time for Your Medicine!"
        content.body = "Your medication reminder is ready."
        content.sound = .default
        content.categoryIdentifier = "MEDIMATEGROUP"
        content.userInfo = info
        let request = UNNotificationRequest(identifier: "medimate|snooze|\(occurrenceID)", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, minutes) * 60), repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        Task { @MainActor in
            defer { completionHandler() }
            guard let container = self.container else { return }
            let context = ModelContext(container)
            guard let occurrenceID = info["occurrenceID"] as? String,
                  let medString = info["medicineID"] as? String, let medicineID = UUID(uuidString: medString),
                  let scheduleString = info["scheduleID"] as? String, let scheduleID = UUID(uuidString: scheduleString),
                  let timestamp = info["scheduledAt"] as? TimeInterval else { return }
            let meds = (try? context.fetch(FetchDescriptor<Medicine>())) ?? []
            guard let med = meds.first(where: { $0.id == medicineID }) else { return }
            let time = Date(timeIntervalSince1970: timestamp)
            let occurrence = DoseOccurrence(id: occurrenceID, medicineID: medicineID, name: med.name,
                                            dosage: med.dosage, date: time, units: med.unitsPerDose, scheduleID: scheduleID)
            switch response.actionIdentifier {
            case "DOSE_TAKEN": try? DoseService.record("taken", occurrence: occurrence, medicine: med, context: context)
            case "DOSE_SKIP": try? DoseService.record("skipped", occurrence: occurrence, medicine: med, context: context)
            case "DOSE_SNOOZE":
                let logged = (try? context.fetch(FetchDescriptor<DoseLog>()))?.contains(where: { $0.occurrenceID == occurrenceID }) ?? false
                if !logged {
                    let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first
                    if settings?.medicationReminders == true {
                        await self.snooze(info: info, minutes: settings?.snoozeMinutes ?? 15)
                    }
                }
            default: break
            }
            if response.actionIdentifier != "DOSE_SNOOZE" { await refresh(context: context) }
        }
    }
}
