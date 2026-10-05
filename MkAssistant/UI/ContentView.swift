import SwiftUI

struct ContentView: View {
    @EnvironmentObject var assistant: AssistantController

    var body: some View {
        VStack(spacing: 24) {
            Text("MK")
                .font(.system(size: 64, weight: .bold))

            Text(assistant.state.label)
                .font(.title2)

            Text(assistant.lastTranscript.isEmpty ? "Say “Hey MK”" : assistant.lastTranscript)
                .multilineTextAlignment(.center)
                .padding()

            if !assistant.lastResponse.isEmpty {
                Text("MK: \(assistant.lastResponse)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Button("Start Voice Test") {
                assistant.testListen()
            }
            .buttonStyle(.borderedProminent)

            Button("Test Speaker") {
                assistant.testSpeaker()
            }
            .buttonStyle(.bordered)

            Button("Stop") {
                assistant.stopListening()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
