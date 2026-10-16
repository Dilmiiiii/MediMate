import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct MedicineFormView: View {
    let editID: UUID?
    let prefill: ScannedMedicine?
    let onScan: () -> Void
    let onDone: () -> Void
    @Environment(\.modelContext) private var context
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @State private var name = ""
    @State private var type = "Tablet"
    @State private var dosage = ""
    @State private var strength = ""
    @State private var expiryDateText = ""
    @State private var notes = ""
    @State private var frequency = "Daily"
    @State private var intervalHours = 8
    @State private var times: [Date] = [Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now]
    @State private var weekdays: Set<Int> = [2,3,4,5,6]
    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(86400 * 14)
    @State private var hasEndDate = false
    @State private var stock = 20
    @State private var unitsPerDose = 1
    @State private var threshold = 5
    @State private var unit = "tablets"
    @State private var notifications = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var loaded = false
    @State private var error: String?
    @State private var showSaved = false
    private let weekdaysText = [(1,"Sun"),(2,"Mon"),(3,"Tue"),(4,"Wed"),(5,"Thu"),(6,"Fri"),(7,"Sat")]

    var body: some View {
        Form {
            if editID == nil {
                Section {
                    Button(action: onScan) {
                        Label("Scan Medicine Label", systemImage: "viewfinder")
                    }
                    Text("Quickly fill in medication details using your camera.").font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Scan Now") }
            }
            Section("Medication") {
                TextField("Enter medication name", text: $name)
                Picker("Medicine Type", selection: $type) {
                    ForEach(["Tablet", "Capsule", "Syrup", "Drops", "Other"], id: \.self) { Text($0) }
                }
                TextField("Prescribed Dosage", text: $dosage, prompt: Text("e.g. 1 tablet"))
                TextField("Strength (optional)", text: $strength)
                TextField("Expiry Date (if known)", text: $expiryDateText)
                VStack(alignment: .leading) {
                    Text("Additional Notes").font(.subheadline)
                    TextEditor(text: $notes).frame(height: 75)
                }
            }
            Section("Reminder Schedule") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(["Daily", "Specific days", "Every X hours", "Custom"], id: \.self) { Text($0) }
                }
                if frequency == "Specific days" {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Days to remind").font(.subheadline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 5) {
                            ForEach(weekdaysText, id: \.0) { day in
                                Button(day.1) {
                                    if weekdays.contains(day.0) { weekdays.remove(day.0) } else { weekdays.insert(day.0) }
                                }.font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(weekdays.contains(day.0) ? MediTheme.green : MediTheme.pale, in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(weekdays.contains(day.0) ? .white : MediTheme.green)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                if frequency == "Every X hours" {
                    Stepper("Repeat every \(intervalHours) hours", value: $intervalHours, in: 2...24)
                    Text("Starts at the first reminder time and repeats until the end of the day.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(times.indices, id: \.self) { index in
                    HStack {
                        DatePicker("Reminder Time \(index + 1)", selection: $times[index], displayedComponents: .hourAndMinute)
                        if times.count > 1 { Button(role: .destructive) { times.remove(at: index) } label: { Image(systemName: "minus.circle") } }
                    }
                }
                Button { times.append(Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now) } label: {
                    Label("Add Reminder Time", systemImage: "plus.circle")
                }
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                Toggle("Set End Date", isOn: $hasEndDate)
                if hasEndDate { DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date) }
                Toggle("Notifications Enabled", isOn: $notifications)
            }
            Section("Inventory") {
                Stepper("Remaining Stock: \(stock)", value: $stock, in: 0...100_000)
                Stepper("Consumed per taken dose: \(unitsPerDose)", value: $unitsPerDose, in: 1...100)
                Stepper("Refill Threshold: \(threshold)", value: $threshold, in: 0...100_000)
                TextField("Stock unit", text: $unit)
            }
            Section("Medicine Photo") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Choose Photo", systemImage: "photo") }
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage).resizable().scaledToFit().frame(height: 120)
                }
            }
            Section {
                Text("Enter prescribed information only. MediMate does not prescribe or determine medication dosages.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(editID == nil ? "Save Medication" : "Save Changes", action: save)
                    .buttonStyle(PrimaryButtonStyle()).listRowBackground(Color.clear)
            }
        }
        .navigationTitle(editID == nil ? "Add Medication" : "Edit Medication")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadInitial)
        .onChange(of: selectedPhoto) { _, item in
            Task { photoData = try? await item?.loadTransferable(type: Data.self) }
        }
        .alert("Check Medication Details", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
        .alert("Medication Added!", isPresented: $showSaved) {
            Button("Done", action: onDone)
        } message: { Text("Your medication has been saved successfully.") }
    }

    private func loadInitial() {
        guard !loaded else { return }
        loaded = true
        if let id = editID, let medicine = medicines.first(where: { $0.id == id }) {
            name = medicine.name; type = medicine.type; dosage = medicine.dosage
            strength = medicine.strength; expiryDateText = medicine.expiryDateText; notes = medicine.instructions
            frequency = medicine.frequency; intervalHours = medicine.intervalHours
            startDate = medicine.startDate
            hasEndDate = medicine.endDate != nil; endDate = medicine.endDate ?? endDate
            stock = medicine.stock; unitsPerDose = medicine.unitsPerDose
            threshold = medicine.refillThreshold; unit = medicine.unit
            notifications = medicine.notificationsEnabled; photoData = medicine.photo
            let plans = schedules.filter { $0.medicineID == id }
            if let first = plans.first, !first.weekdays.isEmpty { weekdays = Set(first.weekdays) }
            let dates = plans.compactMap { Calendar.current.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: .now) }
            if !dates.isEmpty { times = dates }
        } else if let prefill {
            name = prefill.name; strength = prefill.strength; expiryDateText = prefill.expiry; notes = prefill.instructions
        }
    }

    private func save() {
        let slots = MedicationEngine.suggestedSchedule(frequency: frequency, times: times,
                                                       weekdays: Array(weekdays), intervalHours: intervalHours)
        if let validationError = MedicineFormViewModel.error(name: name, prescribedDosage: dosage,
            frequency: frequency, weekdays: weekdays, startDate: startDate,
            endDate: hasEndDate ? endDate : nil, slots: slots,
            stock: stock, unitsPerDose: unitsPerDose, threshold: threshold) {
            error = validationError; return
        }
        do {
            let medicine: Medicine
            if let id = editID, let current = medicines.first(where: { $0.id == id }) {
                medicine = current
                if current.stock != stock {
                    context.insert(StockEvent(medicineID: id, nameSnapshot: name, change: stock - current.stock, reason: "Manual stock adjustment"))
                }
                for schedule in schedules.filter({ $0.medicineID == id }) { context.delete(schedule) }
            } else {
                medicine = Medicine(name: name, initialStock: stock, stock: stock, sortOrder: medicines.count)
                context.insert(medicine)
            }
            medicine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            medicine.type = type; medicine.dosage = dosage; medicine.strength = strength
            medicine.expiryDateText = expiryDateText.trimmingCharacters(in: .whitespacesAndNewlines)
            medicine.instructions = notes; medicine.frequency = frequency; medicine.intervalHours = intervalHours
            medicine.startDate = startDate; medicine.endDate = hasEndDate ? endDate : nil
            medicine.stock = stock; medicine.unitsPerDose = unitsPerDose; medicine.refillThreshold = threshold
            medicine.unit = unit.isEmpty ? "units" : unit
            medicine.photo = photoData; medicine.notificationsEnabled = notifications
            for slot in slots {
                context.insert(MedicineSchedule(medicineID: medicine.id, hour: slot.hour, minute: slot.minute, weekdays: slot.weekdays,
                                                       validFrom: max(startDate, .now)))
            }
            try context.save()
            Task { await NotificationCoordinator.shared.refresh(context: context) }
            showSaved = true
        } catch { self.error = error.localizedDescription }
    }
}
