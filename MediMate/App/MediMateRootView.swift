import SwiftUI
import SwiftData

enum MediRoute: Hashable {
    case add(ScannedMedicine?)
    case scan
    case detail(UUID)
    case edit(UUID)
    case stock
    case settings
}

enum MediTab: Int, Hashable { case home, medicines, history, insights, profile }

struct MediMateRootView: View {
    @AppStorage("medimate.onboarding.finished") private var finishedOnboarding = false
    @State private var splashVisible = true
    @State private var route: [MediRoute] = []
    @State private var tab: MediTab = .home
    @Query private var preferences: [AppSettings]
    @Environment(\.dynamicTypeSize) private var systemTextSize
    private var scheme: ColorScheme? {
        switch preferences.first?.appearance {
        case "Light Mode": return .light
        case "Dark Mode": return .dark
        default: return nil
        }
    }
    var body: some View {
        Group {
            if splashVisible { SplashView() }
            else if !finishedOnboarding {
                OnboardingView { finishedOnboarding = true }
            } else {
                NavigationStack(path: $route) {
                    TabView(selection: $tab) {
                        HomeView(onAdd: { route.append(.add(nil)) }, onScan: { route.append(.scan) },
                                 onMedicine: { route.append(.detail($0)) }, onStock: { route.append(.stock) })
                            .tabItem { Label("Home", systemImage: "house.fill") }.tag(MediTab.home)
                        MedicinesView(onAdd: { route.append(.add(nil)) }, onMedicine: { route.append(.detail($0)) },
                                      onEdit: { route.append(.edit($0)) })
                            .tabItem { Label("Medicines", systemImage: "pills.fill") }.tag(MediTab.medicines)
                        HistoryView()
                            .tabItem { Label("History", systemImage: "calendar") }.tag(MediTab.history)
                        InsightsView()
                            .tabItem { Label("Insights", systemImage: "chart.bar.fill") }.tag(MediTab.insights)
                        ProfileView(onSettings: { route.append(.settings) })
                            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }.tag(MediTab.profile)
                    }
                    .navigationDestination(for: MediRoute.self) { destination in
                        switch destination {
                        case .add(let prefill):
                            MedicineFormView(editID: nil, prefill: prefill,
                                             onScan: { route.append(.scan) }, onDone: { route.removeAll() })
                        case .scan:
                            ScannerView(onVerified: { scanned in
                                if !route.isEmpty { route.removeLast() }
                                route.append(.add(scanned))
                            })
                        case .detail(let id):
                            MedicineDetailView(medicineID: id,
                                               onEdit: { route.append(.edit(id)) },
                                               onHistory: { route.removeAll(); tab = .history },
                                               onDone: { route.removeAll() })
                        case .edit(let id):
                            MedicineFormView(editID: id, prefill: nil,
                                             onScan: { route.append(.scan) }, onDone: { route.removeAll(); tab = .medicines })
                        case .stock: StockView()
                        case .settings: SettingsView(onDeleted: { route.removeAll(); tab = .home })
                        }
                    }
                }
            }
        }
        .tint(MediTheme.green)
        .preferredColorScheme(scheme)
        .dynamicTypeSize(preferences.first?.largerText == true && systemTextSize < .xxxLarge ? .xxxLarge : systemTextSize)
        .task {
            guard splashVisible else { return }
            try? await Task.sleep(for: .milliseconds(1050))
            withAnimation(.easeInOut(duration: 0.3)) { splashVisible = false }
        }
    }
}

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [MediTheme.green, Color(red: 0.08, green: 0.34, blue: 0.37)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 15) {
                Image(systemName: "pills.fill").font(.system(size: 80)).symbolRenderingMode(.hierarchical)
                    .scaleEffect(appeared ? 1 : 0.72)
                Text("MediMate").font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Your Health, Right on Time.").font(.headline).opacity(0.9)
                Spacer().frame(height: 55)
                Text("A smarter way to manage your medications.").font(.footnote).opacity(0.82)
            }.foregroundStyle(.white).multilineTextAlignment(.center).padding(32)
        }.onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.8)) { appeared = true } }
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var index = 0
    private let pages: [(symbol: String, title: String, description: String)] = [
        ("alarm.fill", "Never Miss a Dose", "Stay on top of your medication routine with timely reminders designed around your schedule."),
        ("viewfinder", "Scan & Organize", "Easily add medications by scanning their labels and keeping everything organized in one place."),
        ("chart.line.uptrend.xyaxis", "Track Your Progress", "View your medication history, monitor your routine, and stay informed about upcoming refills.")
    ]
    var body: some View {
        VStack(spacing: 26) {
            HStack { Spacer(); Button("Skip", action: onFinish).font(.subheadline.weight(.semibold)) }.padding(.top, 12)
            Spacer()
            Image(systemName: pages[index].symbol).font(.system(size: 85))
                .foregroundStyle(MediTheme.green).frame(width: 160, height: 160)
                .background(MediTheme.pale, in: RoundedRectangle(cornerRadius: 42))
                .contentTransition(.symbolEffect(.replace))
            Text(pages[index].title).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(pages[index].description).font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 10)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { page in
                    Capsule().fill(page == index ? MediTheme.green : MediTheme.green.opacity(0.2))
                        .frame(width: page == index ? 24 : 8, height: 8)
                }
            }
            Button(index == 2 ? "Get Started" : "Next") {
                if index == 2 { onFinish() }
                else { withAnimation(.easeInOut) { index += 1 } }
            }.buttonStyle(PrimaryButtonStyle())
        }.padding(26).background(MediTheme.canvas).accessibilityElement(children: .contain)
    }
}
