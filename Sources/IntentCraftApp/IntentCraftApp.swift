import SwiftUI

@main
struct IntentCraftApp: App {
    var body: some Scene {
        WindowGroup("IntentCraft") {
            ContentView()
                .frame(minWidth: 920, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {} // single-window utility app
        }
    }
}
