import AppIntents
import ShotWorkflow

// App Shortcuts (spoken phrases / Spotlight tiles) are only discovered when the
// `AppShortcutsProvider` is compiled into the app target, because Xcode's App Intents
// metadata processor runs on the app bundle. The intent types live in ShotWorkflow.

struct ShotShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureIntent(),
            phrases: [
                "Take a screenshot with \(.applicationName)",
                "Capture \(\.$mode) with \(.applicationName)",
            ],
            shortTitle: "Take Screenshot",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: RunWorkflowIntent(),
            phrases: [
                "Run \(\.$workflow) in \(.applicationName)",
                "Run a \(.applicationName) workflow",
            ],
            shortTitle: "Run Workflow",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: RecognizeTextIntent(),
            phrases: [
                "Capture text with \(.applicationName)",
                "Copy text from screen with \(.applicationName)",
            ],
            shortTitle: "Capture Text",
            systemImageName: "text.viewfinder"
        )
    }
}
