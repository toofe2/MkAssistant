import SwiftUI

struct ContentView: View {
    @EnvironmentObject var assistant: AssistantController

    var body: some View {
        VStack(spacing: 24) {
            Text("MK").font(.system(size: 64, weight: .bold))
            Text(assistant.state.label).font(.title2)
            Text(assistant.lastTranscript.isEmpty ? "Say “Hey MK”" : assistant.lastTranscript)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}
