import SwiftUI
import SwiftData

struct StockView: View {
    @Query private var medicines: [Medicine]
    @Query(sort: \StockEvent.createdAt, order: .reverse) private var history: [StockEvent]
    @Environment(\.modelContext) private var context
    @State private var selected: UUID?
    @State private var refill = 10
    @State private var threshold = 5
    @State private var issue: String?
    private var low: [Medicine] { medicines.filter { $0.isActive && $0.stock <= $0.refillThreshold } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Keep track of your remaining medications.").foregroundStyle(.secondary)
                if !low.isEmpty {
                    Label("Low Stock Alert — \(low.count) medication(s) may need a refill soon.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(MediTheme.amber).mediCard()
                }
                ForEach(medicines, id: \.id) { med in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text(med.name).font(.headline); Spacer(); Text("\(med.stock) \(med.unit)").font(.headline) }
                        ProgressView(value: Double(max(0, med.stock)), total: Double(max(1, med.initialStock)))
                            .tint(med.stock <= med.refillThreshold ? MediTheme.amber : MediTheme.green)
                        Text(med.stock <= med.refillThreshold ? "Low Stock" : "In Stock")
                            .font(.caption.bold()).foregroundStyle(med.stock <= med.refillThreshold ? MediTheme.amber : MediTheme.green)
                        Text("Initial stock: \(med.initialStock) \(med.unit). Estimated quantity remaining.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Update Stock") { selected = med.id; threshold = med.refillThreshold; refill = 10 }
                            .buttonStyle(.bordered)
                    }.mediCard()
                }
                Text("Inventory History").font(.title3.bold())
                if history.isEmpty { EmptyStateView(symbol: "archivebox", title: "No Inventory History", message: "Stock changes appear after doses or purchases.") }
                ForEach(history.prefix(30), id: \.id) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.nameSnapshot).font(.headline)
                            Text("\(event.reason) · \(event.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.change > 0 ? "+\(event.change)" : "\(event.change)").font(.headline.monospacedDigit())
                            .foregroundStyle(event.change > 0 ? MediTheme.green : MediTheme.red)
                    }.mediCard()
                }
            }.padding(18)
        }.background(MediTheme.canvas).navigationTitle("Medicine Inventory")
            .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) { editor }
            .alert("Unable to save inventory", isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })) {
                Button("OK", role: .cancel) { issue = nil }
            } message: { Text(issue ?? "") }
    }
    private var editor: some View {
        NavigationStack {
            Form {
                Section("Add Purchased Quantity") { Stepper("Add \(refill) units", value: $refill, in: 1...100_000) }
                Section("Set Refill Threshold") { Stepper("Alert when remaining ≤ \(threshold)", value: $threshold, in: 0...100_000) }
                Button("Save Inventory Changes") {
                    guard let selected, let med = medicines.first(where: { $0.id == selected }) else { return }
                    do {
                        try DoseService.restock(refill, medicine: med, context: context)
                        med.refillThreshold = threshold
                        try context.save()
                        self.selected = nil
                    } catch { issue = error.localizedDescription }
                }.buttonStyle(PrimaryButtonStyle())
            }.navigationTitle("Update Stock").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { selected = nil } } }
        }.presentationDetents([.medium])
    }
}
