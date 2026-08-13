import SwiftUI

@main
@MainActor
struct StubApp: App {
    @StateObject private var store = ArchiveStore()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(store)
        }
    }
}
