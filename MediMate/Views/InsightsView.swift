import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @Query private var logs: [DoseLog]
    @State private var exportURL: URL?
    private var start: Date { Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) ?? .now }
    private func occurrences(start: Date, days: Int) -> [DoseOccurrence] {
        let computed = MedicationEngine.range(start: start, days: days, medicines: medicines, schedules: schedules)
        let computedIDs = Set(computed.map(\.id))
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: start) else { return computed }
        let archived = logs.filter {
            $0.scheduledAt >= start && $0.scheduledAt < end && !computedIDs.contains($0.occurrenceID)
        }.map { log in
            DoseOccurrence(id: log.occurrenceID, medicineID: log.medicineID, name: log.nameSnapshot,
                           dosage: "Recorded dose", date: log.scheduledAt, units: 0, scheduleID: UUID())
        }
        return (computed + archived).sorted { $0.date < $1.date }
    }
    private var weekly: [DoseOccurrence] { occurrences(start: start, days: 7) }
    private var monthly: [DoseOccurrence] {
        let cal = Calendar.current
        let first = cal.dateInterval(of: .month, for: .now)?.start ?? .now
        let days = cal.range(of: .day, in: .month, for: .now)?.count ?? 30
        return occurrences(start: first, days: days)
    }
    private var monthlyDue: [DoseOccurrence] { monthly.filter { $0.date <= .now } }
    private var monthlyTaken: Int { monthlyDue.filter { MedicationEngine.status(for: $0, logs: logs) == "taken" }.count }
    private var due: [DoseOccurrence] { weekly.filter { $0.date <= .now } }
    private var taken: Int { due.filter { MedicationEngine.status(for: $0, logs: logs) == "taken" }.count }
    private var skipped: Int { due.filter { MedicationEngine.status(for: $0, logs: logs) == "skipped" }.count }
    private var missed: Int { due.filter { MedicationEngine.status(for: $0, logs: logs) == "missed" }.count }
    private var dayCounts: [(date: Date, taken: Int, missed: Int)] {
        (0..<7).compactMap { index in
            guard let day = Calendar.current.date(byAdding: .day, value: index, to: start) else { return nil }
            let today = weekly.filter { Calendar.current.isDate($0.date, inSameDayAs: day) && $0.date <= .now }
            return (day, today.filter { MedicationEngine.status(for: $0, logs: logs) == "taken" }.count,
                    today.filter { MedicationEngine.status(for: $0, logs: logs) == "missed" }.count)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Understand your medication routine.").foregroundStyle(.secondary)
                HStack(spacing: 15) {
                    ProgressRing(progress: MedicationEngine.adherence(occurrences: weekly, logs: logs), label: "this week")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Adherence").font(.headline)
                        Text("\(taken) taken / \(due.count) due doses").font(.subheadline)
                        Text("Only doses due by now are counted. A skipped dose is not taken.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.mediCard()
                HStack(spacing: 10) {
                    StatTile(title: "Taken", value: "\(taken)", symbol: "checkmark.circle.fill")
                    StatTile(title: "Missed", value: "\(missed)", symbol: "xmark.circle.fill")
                    StatTile(title: "Skipped", value: "\(skipped)", symbol: "minus.circle.fill")
                }
                VStack(alignment: .leading, spacing: 15) {
                    Text("Weekly Activity").font(.headline)
                    if due.isEmpty {
                        Text("No scheduled doses are due yet.").foregroundStyle(.secondary)
                    } else {
                        Chart {
                            ForEach(dayCounts, id: \.date) { count in
                                BarMark(x: .value("Day", count.date, unit: .day), y: .value("Taken", count.taken))
                                    .foregroundStyle(MediTheme.green).position(by: .value("Status", "Taken"))
                                BarMark(x: .value("Day", count.date, unit: .day), y: .value("Missed", count.missed))
                                    .foregroundStyle(MediTheme.red).position(by: .value("Status", "Missed"))
                            }
                        }.chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                            .frame(height: 215)
                    }
                }.mediCard()
                HStack(spacing: 10) {
                    StatTile(title: "Current Streak", value: "\(MedicationEngine.streak(occurrences: weekly, logs: logs)) days", symbol: "flame")
                    StatTile(title: "Due This Week", value: "\(due.count)", symbol: "calendar.badge.clock")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monthly Adherence").font(.headline)
                    let percentage = MedicationEngine.adherence(occurrences: monthly, logs: logs)
                    Text("\(Int(percentage * 100))% · \(monthlyTaken) taken of \(monthlyDue.count) due doses this month")
                        .font(.title3.bold())
                    ProgressView(value: percentage).tint(MediTheme.green)
                    Text("Calculated from recorded and scheduled medication activity.")
                        .font(.caption).foregroundStyle(.secondary)
                }.mediCard()
                Text("Adherence is confirmed Taken doses divided by doses that are due as of now. Upcoming doses are excluded.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Prepare History Report") { exportURL = ReportExporter.csv(logs: logs) }
                    .buttonStyle(PrimaryButtonStyle())
                if let exportURL { ShareLink(item: exportURL) { Label("Export Medication History (CSV)", systemImage: "square.and.arrow.up") } }
            }.padding(18)
        }.background(MediTheme.canvas).navigationTitle("Health Insights")
    }
}
