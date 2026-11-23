import SwiftUI
import RecipeCore

@main
struct RecipeManagerApp: App {
    var body: some Scene {
        WindowGroup("Fujifilm Recipe Manager") {
            VStack(alignment: .leading, spacing: 18) {
                Label("Fujifilm Recipe Manager", systemImage: "camera")
                    .font(.largeTitle)
                Text("Phase 1 · Research and project foundation")
                    .font(.headline)
                Text("Target camera: \(ProjectScope.cameraModel)")
                Text("Custom banks: \(ProjectScope.customSlotLabels.joined(separator: ", "))")
                Text(ProjectScope.communicationStatus)
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("This project shell does not connect to a camera. Recipe library, backup tools, and USB access are planned for later phases.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(32)
            .frame(minWidth: 560, idealWidth: 620, minHeight: 300)
        }
    }
}
