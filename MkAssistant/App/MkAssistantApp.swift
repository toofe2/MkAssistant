import SwiftUI

@main
struct MkAssistantApp: App {
    @StateObject private var assistant = AssistantController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(assistant)
                .task { assistant.start() }
        }
    }
}
