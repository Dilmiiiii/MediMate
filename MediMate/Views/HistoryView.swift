import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @Query private var logs: [DoseLog]
    @State private var month = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var filter = "Daily"
    @State private var chosenMedicine = "All"
    @State private var action: DoseOccurrence?
    private let calendar = Calendar.current
    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = calendar.component(.weekday, from: interval.start) - 1
        return (0..<(offset + range.count)).compactMap { idx in
            idx < offset ? nil : calendar.date(byAdding: .day, value: idx - offset, to: interval.start)
        }
    }
    // Recorded occurrences remain visible even after edits, pauses, or deletion.
    private func on(_ day: Date) -> [DoseOccurrence] {
        let computed = MedicationEngine.due(on: day, medicines: medicines, schedules: schedules)
        let computedIDs = Set(computed.map(\.id))
        let archived = logs.filter { log in
            calendar.isDate(log.scheduledAt, inSameDayAs: day) && !computedIDs.contains(log.occurrenceID)
        }.map { log in
            DoseOccurrence(id: log.occurrenceID, medicineID: log.medicineID,
                           name: log.nameSnapshot, dosage: "Recorded dose", date: log.scheduledAt,
                           units: 0, scheduleID: UUID())
        }
        return (computed + archived)
            .filter { chosenMedicine == "All" || $0.medicineID.uuidString == chosenMedicine }
            .sorted { $0.date < $1.date }
    }
    private var entries: [DoseOccurrence] {
        let beginning: Date
        let count: Int
        switch filter {
        case "Weekly":
            beginning = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            count = 7
        case "Monthly":
            beginning = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            count = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        default: beginning = selectedDate; count = 1
        }
        return (0..<count).flatMap { offset -> [DoseOccurrence] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: beginning) else { return [] }
            return on(day)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Track your medication routine.").foregroundStyle(.secondary)
                VStack(spacing: 16) {
                    HStack {
                        Button { stepMonth(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                        Spacer()
                        Button { stepMonth(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
                    }
                    HStack {
                        ForEach(["S","M","T","W","T","F","S"].indices, id: \.self) { index in
                            Text(["S","M","T","W","T","F","S"][index]).font(.caption.bold())
                                .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                        let leading = calendar.component(.weekday, from: calendar.dateInterval(of: .month, for: month)?.start ?? month) - 1
                        ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 49) }
                        ForEach(days, id: \.self) { date in
                            let dayOccurrences = on(date)
                            let taken = dayOccurrences.filter { MedicationEngine.status(for: $0, logs: logs) == "taken" }.count
                            Button {
                                selectedDate = date
                            } label: {
                                VStack(spacing: 5) {
                                    Text("\(calendar.component(.day, from: date))").font(.subheadline.bold())
                                    Circle().fill(dayOccurrences.isEmpty ? Color.clear : taken == dayOccurrences.count ? MediTheme.green : MediTheme.amber)
                                        .frame(width: 5, height: 5)
                                }.frame(maxWidth: .infinity).frame(height: 45)
                                    .background(calendar.isDate(date, inSameDayAs: selectedDate) ? MediTheme.pale : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }.mediCard()
                Picker("Period", selection: $filter) {
                    ForEach(["Daily","Weekly","Monthly"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                Picker("Medication", selection: $chosenMedicine) {
                    Text("All Medications").tag("All")
                    ForEach(medicines, id: \.id) { med in Text(med.name).tag(med.id.uuidString) }
                }
                Text("Medication History").font(.title3.bold())
                if entries.isEmpty {
                    EmptyStateView(symbol: "calendar.badge.clock", title: "No History Available", message: "Your medication records will appear here.")
                } else {
                    ForEach(entries) { entry in
                        Button { if medicines.contains(where: { $0.id == entry.medicineID }) { action = entry } } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.name).font(.headline)
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                    if !medicines.contains(where: { $0.id == entry.medicineID }) {
                                        Text("Archived record").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                DoseChip(status: MedicationEngine.status(for: entry, logs: logs))
                            }.mediCard()
                        }.buttonStyle(.plain)
                            .disabled(!medicines.contains(where: { $0.id == entry.medicineID }))
                    }
                }
                HStack(spacing: 12) {
                    ForEach(["taken","missed","skipped","upcoming"], id: \.self) { DoseChip(status: $0) }
                }.frame(maxWidth: .infinity).minimumScaleFactor(0.7)
            }.padding(18)
        }.navigationTitle("Medication History").background(MediTheme.canvas)
            .sheet(item: $action) { DoseActionSheet(occurrence: $0, onError: { _ in }) }
    }
    private func stepMonth(_ count: Int) {
        guard let date = calendar.date(byAdding: .month, value: count, to: month) else { return }
        month = date; selectedDate = calendar.dateInterval(of: .month, for: date)?.start ?? date
    }
}
