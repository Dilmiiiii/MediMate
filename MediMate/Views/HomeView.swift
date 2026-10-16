import SwiftUI
import SwiftData

struct HomeView: View {
    let onAdd: () -> Void
    let onScan: () -> Void
    let onMedicine: (UUID) -> Void
    let onStock: () -> Void
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @Query private var logs: [DoseLog]
    @Query private var profiles: [UserProfile]
    @Query private var settings: [AppSettings]
    @Environment(\.modelContext) private var context
    @State private var selection: DoseOccurrence?
    @State private var error: String?
    private var summary: DashboardViewModel.Summary {
        DashboardViewModel.today(medicines: medicines, schedules: schedules, logs: logs)
    }
    private var today: [DoseOccurrence] { summary.doses }
    private var done: Int { summary.taken }
    private var next: DoseOccurrence? { summary.next }
    private var name: String { profiles.first?.fullName.components(separatedBy: " ").first ?? "Alex" }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening"
    }
    private var lowStock: [Medicine] { DashboardViewModel.lowStock(medicines: medicines) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).foregroundStyle(.secondary).font(.subheadline)
                    Text("\(greeting), \(name)!")
                        .font(.largeTitle.bold()).minimumScaleFactor(0.8)
                    Text("Let’s stay on track with your health.").foregroundStyle(.secondary)
                }
                HStack(spacing: 18) {
                    ProgressRing(progress: summary.progress, label: "today")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today’s Progress").font(.headline)
                        Text("\(done) of \(today.count) scheduled doses recorded as taken.").font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Every step counts.").font(.caption).foregroundStyle(MediTheme.green)
                    }
                }.mediCard()
                HStack {
                    Text("Quick Actions").font(.title3.bold())
                    Spacer()
                }
                HStack(spacing: 12) {
                    action("Add Medicine", symbol: "plus.circle.fill", onAction: onAdd)
                    action("Scan Label", symbol: "viewfinder", onAction: onScan)
                }
                if let next {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Next Medication", systemImage: "clock.badge.checkmark").foregroundStyle(MediTheme.green).font(.headline)
                        Text(next.name).font(.title3.bold())
                        Text("\(next.dosage) · \(next.date.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(.secondary)
                        Button("View Reminder") { selection = next }.buttonStyle(PrimaryButtonStyle())
                    }.mediCard()
                }
                if (settings.first?.refillAlerts ?? true) && !lowStock.isEmpty {
                    Button(action: onStock) {
                        HStack {
                            Image(systemName: "shippingbox.fill").font(.title2)
                            VStack(alignment: .leading) {
                                Text("Time to Refill").font(.headline)
                                Text("\(lowStock.count) medication(s) may need a refill soon.").font(.caption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }.foregroundStyle(MediTheme.amber).mediCard()
                    }.buttonStyle(.plain)
                }
                HStack {
                    Text("Today’s Schedule").font(.title3.bold())
                    Spacer()
                    Button("Inventory", action: onStock).font(.subheadline.bold())
                }
                if today.isEmpty {
                    EmptyStateView(symbol: "pills", title: "No Medications Yet", message: "Add your first medication to get started.")
                    Button("Add Medication", action: onAdd).buttonStyle(PrimaryButtonStyle())
                } else {
                    ForEach(today) { occurrence in
                        Button { selection = occurrence } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(occurrence.date.formatted(date: .omitted, time: .shortened)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(occurrence.name).font(.headline)
                                    Text(occurrence.dosage).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                DoseChip(status: MedicationEngine.status(for: occurrence, logs: logs))
                            }.mediCard()
                        }.buttonStyle(.plain).accessibilityHint("Open dose response actions")
                        .contextMenu { Button("Medicine Details") { onMedicine(occurrence.medicineID) } }
                    }
                }
            }.padding(18)
        }.background(MediTheme.canvas).navigationTitle("MediMate")
            .sheet(item: $selection) { DoseActionSheet(occurrence: $0, onError: { error = $0 }) }
            .alert("Unable to update dose", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
    private func action(_ title: String, symbol: String, onAction: @escaping () -> Void) -> some View {
        Button(action: onAction) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.subheadline.bold())
            }.foregroundStyle(MediTheme.green).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(MediTheme.pale.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct DoseActionSheet: View {
    let occurrence: DoseOccurrence
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var medicines: [Medicine]
    @Query private var logs: [DoseLog]
    @Query private var preferences: [AppSettings]
    @State private var snoozed = false
    private var record: DoseLog? { logs.first { $0.occurrenceID == occurrence.id } }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Time for Your Medicine!", systemImage: "pills.fill").font(.title2.bold()).foregroundStyle(MediTheme.green)
                    Text("It’s time for your scheduled dose.").foregroundStyle(.secondary)
                    Text(occurrence.name).font(.title.bold())
                    Text("\(occurrence.dosage) · Scheduled Time: \(occurrence.date.formatted(date: .omitted, time: .shortened))")
                    if let record { DoseChip(status: record.status) }
                }.mediCard()
                Button("Mark as Taken") { apply("taken") }.buttonStyle(PrimaryButtonStyle())
                Button("Remind Me Later") {
                    Task {
                        await NotificationCoordinator.shared.snooze(info: [
                            "occurrenceID": occurrence.id, "medicineID": occurrence.medicineID.uuidString,
                            "scheduleID": occurrence.scheduleID.uuidString, "scheduledAt": occurrence.date.timeIntervalSince1970
                        ], minutes: preferences.first?.snoozeMinutes ?? 15)
                        snoozed = true
                    }
                }.buttonStyle(.borderedProminent).tint(MediTheme.amber).disabled(record != nil)
                Button("Skip This Dose") { apply("skipped") }.buttonStyle(.bordered)
                if snoozed { Label("Follow-up reminder scheduled.", systemImage: "checkmark.circle.fill").foregroundStyle(MediTheme.green) }
                Text("Do not double a missed dose. Follow your prescription or consult your healthcare professional.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }.padding().background(MediTheme.canvas)
                .navigationTitle("Dose Reminder").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
    private func apply(_ status: String) {
        guard let medicine = medicines.first(where: { $0.id == occurrence.medicineID }) else { onError("Medication no longer exists."); return }
        do {
            try DoseService.record(status, occurrence: occurrence, medicine: medicine, context: context)
            Task { await NotificationCoordinator.shared.refresh(context: context) }
            dismiss()
        } catch { onError(error.localizedDescription) }
    }
}
