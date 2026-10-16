import SwiftUI
import SwiftData

@main
struct MediMateApp: App {
    private let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let schema = Schema([Medicine.self, MedicineSchedule.self, DoseLog.self,
                                 StockEvent.self, UserProfile.self, AppSettings.self])
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)])
        } catch {
            fatalError("Unable to initialize MediMate local storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MediMateRootView()
                .modelContainer(container)
                .task {
                    let context = container.mainContext
                    try? DemoSeeder.seedIfNeeded(context: context)
                    NotificationCoordinator.shared.configure(container: container)
                    await NotificationCoordinator.shared.refresh(context: context)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await NotificationCoordinator.shared.refresh(context: container.mainContext) }
                    }
                }
        }
    }
}
