import SwiftUI
import SwiftData

struct MedicinesView: View {
    let onAdd: () -> Void
    let onMedicine: (UUID) -> Void
    let onEdit: (UUID) -> Void
    @Environment(\.modelContext) private var context
    @Query private var medicines: [Medicine]
    @Query private var schedules: [MedicineSchedule]
    @State private var search = ""
    @State private var filter = "All"
    @State private var order = "Custom"
    @State private var selectedForDelete: UUID?
    private var visible: [Medicine] {
        let filtered = medicines.filter {
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) &&
            (filter == "All" || (filter == "Active" ? $0.isActive : !$0.isActive))
        }
        switch order {
        case "Name": return filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case "Stock": return filtered.sorted { $0.stock < $1.stock }
        default: return filtered.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(["All","Active","Inactive"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                Picker("Sort", selection: $order) {
                    ForEach(["Custom","Name","Stock"], id: \.self) { Text($0) }
                }
            }
            if visible.isEmpty {
                EmptyStateView(symbol: "pills", title: "No Medications Yet", message: "Add your first medication to get started.")
                    .listRowBackground(Color.clear)
            }
            ForEach(visible, id: \.id) { medicine in
                Button { onMedicine(medicine.id) } label: {
                    MedicineCard(medicine: medicine, subtitle: "\(medicine.type) · \(timeDescription(medicine)) · \(medicine.isActive ? "Active" : "Inactive")")
                }.buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { selectedForDelete = medicine.id }
                        Button("Edit") { onEdit(medicine.id) }.tint(MediTheme.green)
                    }
                    .contextMenu {
                        Button("View Details") { onMedicine(medicine.id) }
                        Button("Edit") { onEdit(medicine.id) }
                        Button(medicine.isActive ? "Pause" : "Resume") {
                            medicine.isActive.toggle(); try? context.save()
                            Task { await NotificationCoordinator.shared.refresh(context: context) }
                        }
                        Button("Delete", role: .destructive) { selectedForDelete = medicine.id }
                    }
            }.onMove(perform: move)
        }
        .scrollContentBackground(.hidden).background(MediTheme.canvas)
        .searchable(text: $search, prompt: "Search medications...")
        .navigationTitle("My Medications")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: onAdd) { Image(systemName: "plus") }.accessibilityLabel("Add Medication") } }
        .refreshable { await NotificationCoordinator.shared.refresh(context: context) }
        .alert("Delete Medication?", isPresented: Binding(get: { selectedForDelete != nil }, set: { if !$0 { selectedForDelete = nil } })) {
            Button("Delete", role: .destructive, action: deleteSelected)
            Button("Cancel", role: .cancel) { selectedForDelete = nil }
        } message: { Text("This action cannot be undone. Historical dose records will remain in History.") }
    }
    private func timeDescription(_ med: Medicine) -> String {
        schedules.filter { $0.medicineID == med.id }
            .sorted { ($0.hour,$0.minute) < ($1.hour,$1.minute) }
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }.joined(separator: ", ")
    }
    private func deleteSelected() {
        guard let id = selectedForDelete, let medicine = medicines.first(where: { $0.id == id }) else { return }
        schedules.filter { $0.medicineID == id }.forEach(context.delete)
        context.delete(medicine)
        try? context.save()
        selectedForDelete = nil
        Task { await NotificationCoordinator.shared.refresh(context: context) }
    }
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = visible
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, med) in reordered.enumerated() { med.sortOrder = index }
        try? context.save()
    }
}
