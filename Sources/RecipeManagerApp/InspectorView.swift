import SwiftUI

struct InspectorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var inspector = CameraInspector()
    @State private var backupConfirmed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Camera inspector", systemImage: "camera").font(.title2).bold()
            Text("Experimental · identity only").font(.headline).foregroundStyle(.orange)
            Text("This inspector can discover local Fujifilm USB cameras and request model and firmware. It cannot read C1–C4 recipes, select a bank, upload settings or restore backups.")
            Text("Before testing: keep an untouched official settings backup, close other camera apps and confirm the camera is already in the intended USB mode. This app does not change that mode.")
                .foregroundStyle(.secondary)
            Toggle("I have an official backup and am ready for read-only inspection", isOn: $backupConfirmed)
                .disabled(inspector.scanning || inspector.busy)
            HStack {
                Button(inspector.scanning ? "Stop scanning" : "Scan USB cameras") {
                    if inspector.scanning { inspector.stop() } else { inspector.start() }
                }.disabled(!backupConfirmed || inspector.busy)
                Spacer()
                Button("Done") { inspector.stop(); dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(inspector.status).font(.callout).textSelection(.enabled)
            ForEach(Array(inspector.cameras.enumerated()), id: \.offset) { _, camera in
                HStack {
                    Text(camera.name ?? "Fujifilm USB camera")
                    Spacer()
                    Button("Read identity") { inspector.inspect(camera) }.disabled(inspector.busy)
                }
            }
            if inspector.scanning && inspector.cameras.isEmpty {
                Text("No Fujifilm camera is visible yet. This does not establish whether X-M5 recipe access is supported.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let identity = inspector.identity {
                Divider()
                LabeledContent("Manufacturer", value: identity.manufacturer)
                LabeledContent("Model", value: identity.model)
                LabeledContent("Firmware", value: identity.firmware)
                LabeledContent("Advertised properties", value: String(identity.advertisedPropertyCount))
                Text("No compatibility conclusion is drawn from these values.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(24).frame(width: 650, height: 560)
            .onDisappear { inspector.stop() }
    }
}
