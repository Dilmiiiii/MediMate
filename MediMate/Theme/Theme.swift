import SwiftUI

enum MediTheme {
    static let green = Color(red: 0.153, green: 0.529, blue: 0.396)
    static let pale = Color(red: 0.902, green: 0.957, blue: 0.925)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let amber = Color(red: 0.902, green: 0.635, blue: 0.235)
    static let red = Color(red: 0.851, green: 0.357, blue: 0.357)
    static func statusColor(_ status: String) -> Color {
        switch status { case "taken": return green; case "missed": return red
        case "skipped": return amber; default: return .secondary }
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MediTheme.green.opacity(0.07)))
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            .foregroundStyle(.white).background(MediTheme.green, in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.975 : 1).animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
struct ShimmerEffect: ViewModifier {
    @State private var phase = false
    func body(content: Content) -> some View {
        content.overlay(LinearGradient(colors: [.clear, .white.opacity(0.15), .clear],
                                       startPoint: phase ? .trailing : .leading, endPoint: phase ? .leading : .trailing))
            .onAppear { phase = true }.animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: phase)
    }
}
extension View {
    func mediCard() -> some View { modifier(CardStyle()) }
}
