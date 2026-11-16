import SwiftUI

@main
struct CreativeMomentsApp: App {
    @StateObject private var store = PlannerStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store)
                .tint(Color(red: 0.32, green: 0.22, blue: 0.34))
                .preferredColorScheme(.light)
                .alert("Your planner needs attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK") { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
                .onChange(of: scenePhase) { _, phase in if phase != .active { store.flush() } }
        }
    }
}
