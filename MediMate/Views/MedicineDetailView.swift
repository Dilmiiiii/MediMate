import SwiftUI
import SwiftData
import UIKit

struct MedicineDetailView: View {
    let medicineID: UUID
    let onEdit: () -> Void
    let onHistory: () -> Void
    let onDone: () -> Void
    @Environment(\.modelContext) private var context
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @Query private var logs: [DoseLog]
    @State private var chosen: DoseOccurrence?
    @State private var confirmDelete = false
    @State private var issue: String?
    private var medicine: Medicine? { medicines.first { $0.id == medicineID } }
    private var doses: [DoseOccurrence] {
        guard let medicine else { return [] }
        return MedicationEngine.due(on: .now, medicine: medicine, schedules: schedules)
    }
    var body: some View {
        ScrollView {
            if let medicine {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 15) {
                        if let bytes = medicine.photo, let uiImage = UIImage(data: bytes) {
                            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 17))
                        } else {
                            Image(systemName: "pills.fill").font(.largeTitle).foregroundStyle(MediTheme.green)
                                .frame(width: 76, height: 76).background(MediTheme.pale, in: RoundedRectangle(cornerRadius: 17))
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(medicine.name).font(.title2.bold())
                            Text(medicine.isActive ? "Active Medication" : "Paused Medication")
                                .foregroundStyle(medicine.isActive ? MediTheme.green : .secondary)
                            Text(medicine.strength).foregroundStyle(.secondary)
                        }
                    }.mediCard()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Medication Details").font(.headline)
                        detailRow("Type", medicine.type)
                        detailRow("Prescribed Dosage", medicine.dosage)
                        if !medicine.expiryDateText.isEmpty { detailRow("Label Expiry", medicine.expiryDateText) }
                        detailRow("Frequency", medicine.frequency)
                        detailRow("Start Date", medicine.startDate.formatted(date: .abbreviated, time: .omitted))
                        detailRow("End Date", medicine.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "Ongoing")
                        detailRow("Remaining Stock", "\(medicine.stock) \(medicine.unit)")
                        Divider()
                        Text("Reminder Times").font(.headline)
                        ForEach(schedules.filter { $0.medicineID == medicineID }.sorted {
                            ($0.hour,$0.minute) < ($1.hour,$1.minute)
                        }, id: \.id) { schedule in
                            Label(String(format: "%02d:%02d", schedule.hour, schedule.minute), systemImage: "clock")
                                .foregroundStyle(.secondary)
                        }
                    }.mediCard()
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Instructions").font(.headline)
                        Text(medicine.instructions.isEmpty ? "Follow the directions on your prescription label." : medicine.instructions)
                            .foregroundStyle(.secondary)
                    }.mediCard()
                    if !doses.isEmpty {
                        Text("Today's Doses").font(.title3.bold())
                        ForEach(doses) { occurrence in
                            Button { chosen = occurrence } label: {
                                HStack {
                                    Text(occurrence.date.formatted(date: .omitted, time: .shortened))
                                    Spacer()
                                    DoseChip(status: MedicationEngine.status(for: occurrence, logs: logs))
                                }.mediCard()
                            }.buttonStyle(.plain)
                        }
                    }
                    Button("Edit", action: onEdit).buttonStyle(PrimaryButtonStyle())
                    Button("View History", action: onHistory).buttonStyle(.bordered)
                    Button(medicine.isActive ? "Pause Reminders" : "Resume Reminders") {
                        medicine.isActive.toggle()
                        do { try context.save() } catch { issue = error.localizedDescription }
                        Task { await NotificationCoordinator.shared.refresh(context: context) }
                    }.buttonStyle(.bordered)
                    Button("Delete Medication", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    Text("This app never recommends changing or doubling a prescribed dose.").font(.footnote).foregroundStyle(.secondary)
                }.padding(18)
            } else { EmptyStateView(symbol: "exclamationmark.circle", title: "Medication Unavailable", message: "This medication may have been deleted.") }
        }.background(MediTheme.canvas).navigationTitle("Medicine Details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $chosen) { DoseActionSheet(occurrence: $0, onError: { issue = $0 }) }
            .confirmationDialog("Delete Medication?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Medication", role: .destructive) { remove() }
            } message: { Text("This action cannot be undone. Recorded dose history will remain.") }
            .alert("Unable to Update", isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })) {
                Button("OK", role: .cancel) { issue = nil }
            } message: { Text(issue ?? "") }
    }
    private func detailRow(_ title: String, _ content: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(content).multilineTextAlignment(.trailing)
        }.font(.subheadline)
    }
    private func remove() {
        guard let medicine else { return }
        schedules.filter { $0.medicineID == medicineID }.forEach(context.delete)
        context.delete(medicine)
        do { try context.save(); onDone() } catch { issue = error.localizedDescription }
        Task { await NotificationCoordinator.shared.refresh(context: context) }
    }
}
