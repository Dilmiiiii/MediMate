import SwiftUI
import SwiftData

struct SettingsView: View {
    let onDeleted: () -> Void
    @Environment(\.modelContext) private var context
    @Query private var preferences: [AppSettings]
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @Query private var logs: [DoseLog]
    @Query private var stockEvents: [StockEvent]
    @Query private var profiles: [UserProfile]
    @State private var showDelete = false
    @State private var showPrivacy = false
    @State private var exportURL: URL?
    @State private var issue: String?
    private var settings: AppSettings? { preferences.first }
    var body: some View {
        Form {
            if let settings {
                Section("Notifications") {
                    Toggle("Medication Reminders", isOn: makeBinding(settings, \.medicationReminders, refresh: true))
                    Toggle("Refill Alerts", isOn: makeBinding(settings, \.refillAlerts))
                    Stepper("Remind Later: \(settings.snoozeMinutes) minutes", value: makeBinding(settings, \.snoozeMinutes), in: 5...60, step: 5)
                    Button("Allow Notification Permission") {
                        Task {
                            if !(await NotificationCoordinator.shared.requestPermission()) {
                                issue = "Enable Reminders: allow notifications in iOS Settings."
                            } else { await NotificationCoordinator.shared.refresh(context: context) }
                        }
                    }
                }
                Section("Appearance") {
                    Picker("Theme", selection: makeBinding(settings, \.appearance)) {
                        ForEach(["System Default","Light Mode","Dark Mode"], id: \.self) { Text($0) }
                    }
                    Toggle("Larger Text", isOn: makeBinding(settings, \.largerText))
                }
                Section("Language") {
                    Text("English").foregroundStyle(.secondary)
                    Text("Sinhala localization is not included in this demonstration.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Privacy & Data") {
                Button("Export Medication History") { exportURL = ReportExporter.csv(logs: logs) }
                if let exportURL { ShareLink(item: exportURL) { Text("Share CSV History") } }
                Button("Privacy Policy") { showPrivacy = true }
                Button("Delete Local Data", role: .destructive) { showDelete = true }
            }
            Section("About MediMate") {
                Text("MediMate — Your Health, Right on Time.")
                Text("All user data remains on this device. OCR text must be verified. This app does not give medical advice.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Settings")
            .confirmationDialog("Delete Local Data", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) { deleteData() }
            } message: { Text("All medicines, history, stock events and profile data will be permanently deleted from this device.") }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack {
                    ScrollView {
                        Text("Privacy Policy\n\nMediMate stores medication, reminder and profile information locally using SwiftData. No account, external server, or tracking service is required. Camera and photo access is used only for label recognition. Local notifications are scheduled on the device. You may delete local data in Settings. Any CSV export is shared only when you explicitly choose to share it.\n\nMedical disclaimer: This app does not diagnose, recommend dosage changes, or replace advice from a licensed healthcare professional.")
                            .padding(24)
                    }.navigationTitle("Privacy Policy")
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPrivacy = false } } }
                }
            }
            .alert("Settings Notice", isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })) {
                Button("OK", role: .cancel) { issue = nil }
            } message: { Text(issue ?? "") }
    }
    private func makeBinding<Value>(_ model: AppSettings, _ key: ReferenceWritableKeyPath<AppSettings, Value>,
                                    refresh: Bool = false) -> Binding<Value> {
        Binding(get: { model[keyPath: key] }, set: { newValue in
            model[keyPath: key] = newValue
            do { try context.save() } catch { issue = error.localizedDescription }
            if refresh { Task { await NotificationCoordinator.shared.refresh(context: context) } }
        })
    }
    private func deleteData() {
        medicines.forEach(context.delete)
        schedules.forEach(context.delete)
        logs.forEach(context.delete)
        stockEvents.forEach(context.delete)
        profiles.forEach(context.delete)
        preferences.forEach(context.delete)
        context.insert(UserProfile(fullName: "New User"))
        context.insert(AppSettings())
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: "medimate.demo.seeded.v1")
            Task { await NotificationCoordinator.shared.clearAppReminders() }
            onDeleted()
        } catch { issue = error.localizedDescription }
    }
}
