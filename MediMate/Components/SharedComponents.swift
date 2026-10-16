import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let label: String
    var body: some View {
        ZStack {
            Circle().stroke(MediTheme.green.opacity(0.12), lineWidth: 11)
            Circle().trim(from: 0, to: min(1, max(0, progress)))
                .stroke(MediTheme.green, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 0.5), value: progress)
            VStack(spacing: 0) { Text("\(Int(progress * 100))%").font(.title2.bold()); Text(label).font(.caption).foregroundStyle(.secondary) }
        }.frame(width: 118, height: 118).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label), \(Int(progress * 100)) percent")
    }
}
struct DoseChip: View {
    let status: String
    var body: some View {
        Label(status.capitalized, systemImage: status == "taken" ? "checkmark.circle.fill" : status == "skipped" ? "minus.circle.fill" : status == "missed" ? "xmark.circle.fill" : "clock")
            .font(.caption.weight(.semibold)).foregroundStyle(MediTheme.statusColor(status))
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(MediTheme.statusColor(status).opacity(0.1), in: Capsule())
    }
}
struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(MediTheme.green).font(.title3)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.75)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).mediCard()
    }
}
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40)).foregroundStyle(MediTheme.green)
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(26).mediCard()
    }
}
struct MedicineCard: View {
    let medicine: Medicine
    let subtitle: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "pills.fill").font(.title2).foregroundStyle(MediTheme.green)
                .frame(width: 50, height: 50).background(MediTheme.pale, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(medicine.name).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 5)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }.mediCard().accessibilityElement(children: .combine)
    }
}
