import SwiftUI
import SwiftData

@main
struct VoiceCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    RecordView()
                        .navigationDestination(for: Capture.self) { capture in
                            CaptureDetailView(capture: capture)
                        }
                }
                .tabItem {
                    Label("Record", systemImage: "mic")
                }

                NavigationStack {
                    CaptureListView()
                        .navigationTitle("History")
                        .navigationDestination(for: Capture.self) { capture in
                            CaptureDetailView(capture: capture)
                        }
                }
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            }
        }
        .modelContainer(for: Capture.self)
    }
}
