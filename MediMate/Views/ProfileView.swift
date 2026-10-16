import SwiftUI
import SwiftData

struct ProfileView: View {
    let onSettings: () -> Void
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var editing = false
    @State private var name = ""
    @State private var birthdate = Date.now
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var allergies = ""
    @State private var notes = ""
    @State private var issue: String?
    private var profile: UserProfile? { profiles.first }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 55)).foregroundStyle(MediTheme.green)
                    VStack(alignment: .leading) {
                        Text(profile?.fullName ?? "Alex Morgan").font(.title2.bold())
                        Text("Your health profile").foregroundStyle(.secondary)
                    }
                }.mediCard()
                heading("Personal Information")
                line("Full Name", profile?.fullName ?? "Not specified")
                line("Date of Birth", profile?.birthday.formatted(date: .abbreviated, time: .omitted) ?? "Not specified")
                heading("Emergency Contact")
                line("Contact Name", profile?.emergencyName.isEmpty == false ? profile!.emergencyName : "Not specified")
                line("Phone", profile?.emergencyPhone.isEmpty == false ? profile!.emergencyPhone : "Not specified")
                heading("Medical Notes")
                line("Allergies (self-reported)", profile?.allergies.isEmpty == false ? profile!.allergies : "Not provided")
                line("Notes", profile?.medicalNotes.isEmpty == false ? profile!.medicalNotes : "Not provided")
                Button("Edit Profile") { fill(); editing = true }.buttonStyle(PrimaryButtonStyle())
                Button(action: onSettings) {
                    Label("App Settings", systemImage: "gearshape.fill").frame(maxWidth: .infinity, alignment: .leading).mediCard()
                }.buttonStyle(.plain)
                Text("Help & Support: This demonstration stores information locally. For medical emergencies, contact local emergency services.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(18)
        }.background(MediTheme.canvas).navigationTitle("My Profile")
            .sheet(isPresented: $editing) { editor }
            .alert("Unable to Save", isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })) {
                Button("OK", role: .cancel) { issue = nil }
            } message: { Text(issue ?? "") }
    }
    private func heading(_ text: String) -> some View { Text(text).font(.title3.bold()) }
    private func line(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(text).font(.body)
        }.mediCard()
    }
    private func fill() {
        name = profile?.fullName ?? ""
        birthdate = profile?.birthday ?? .now
        contactName = profile?.emergencyName ?? ""
        contactPhone = profile?.emergencyPhone ?? ""
        allergies = profile?.allergies ?? ""
        notes = profile?.medicalNotes ?? ""
    }
    private var editor: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                    DatePicker("Date of Birth", selection: $birthdate, in: ...Date.now, displayedComponents: .date)
                }
                Section("Emergency Contact") {
                    TextField("Contact name", text: $contactName)
                    TextField("Phone", text: $contactPhone).keyboardType(.phonePad)
                }
                Section("Medical Notes") {
                    TextField("Allergies (self-reported)", text: $allergies, axis: .vertical)
                    TextField("Medical Notes", text: $notes, axis: .vertical)
                }
                Button("Save Profile") { save() }.buttonStyle(PrimaryButtonStyle())
            }.navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { editing = false } } }
        }
    }
    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { issue = "Please enter your name."; return }
        let p: UserProfile
        if let profile { p = profile } else { p = UserProfile(); context.insert(p) }
        p.fullName = name; p.birthday = birthdate; p.emergencyName = contactName
        p.emergencyPhone = contactPhone; p.allergies = allergies; p.medicalNotes = notes
        do { try context.save(); editing = false } catch { issue = error.localizedDescription }
    }
}
