import Foundation
import Combine
import ImageCaptureCore
import RecipeCore

/// Created only when the inspector sheet is opened; the browser starts only on an explicit click.
/// No photo requests, tethering, property writes, selectors or arbitrary commands exist here.
final class CameraInspector: NSObject, ObservableObject, ICDeviceBrowserDelegate, ICDeviceDelegate {
    @Published private(set) var cameras: [ICCameraDevice] = []
    @Published private(set) var identity: CameraIdentity?
    @Published private(set) var status = "Not scanning. Camera tests are deferred until an official backup is available."
    @Published private(set) var scanning = false
    @Published private(set) var busy = false
    private var browser: ICDeviceBrowser?
    private var active: ICCameraDevice?
    private var closing = false
    private var token: UUID?
    private var timeout: DispatchWorkItem?

    deinit {
        timeout?.cancel()
        browser?.stop(); browser?.delegate = nil
        active?.delegate = nil
        active?.requestCloseSession()
    }

    func start() {
        guard browser == nil, !busy else { return }
        let browser = ICDeviceBrowser()
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue)!
        self.browser = browser
        scanning = true
        status = "Looking for local Fujifilm USB cameras. No camera session is opened by scanning."
        browser.start()
    }
    func stop() {
        browser?.stop(); browser?.delegate = nil; browser = nil
        cameras = []; scanning = false
        if let camera = active { finish(camera, message: "Inspection cancelled. Closing the session.") }
    }
    func inspect(_ camera: ICCameraDevice) {
        guard !busy, cameras.contains(where: { $0 === camera }), camera.usbVendorID == 0x04cb else { return }
        guard !camera.hasOpenSession else { status = "A session is already open. Close other camera apps and try again."; return }
        guard camera.capabilities.contains(ICDeviceCapability.cameraDeviceCanAcceptPTPCommands.rawValue) else {
            status = "This camera/mode does not advertise PTP pass-through."; return
        }
        busy = true; closing = false; active = camera; identity = nil
        let operation = UUID(); token = operation
        camera.delegate = self
        status = "Opening a session for one GetDeviceInfo request…"
        let deadline = DispatchWorkItem { [weak self, weak camera] in
            guard let self, let camera, self.token == operation else { return }
            self.finish(camera, message: "Inspection timed out. No further commands will be sent.")
        }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: deadline)
        camera.requestOpenSession(options: nil) { [weak self, weak camera] error in
            DispatchQueue.main.async {
                guard let self, let camera else { return }
                guard self.token == operation else { camera.requestCloseSession(); return }
                if error != nil { self.finish(camera, message: "Unable to open the camera session. Check permissions and close other camera apps."); return }
                camera.requestSendPTPCommand(IdentityRequest.command, outData: nil) { [weak self, weak camera] data, response, error in
                    DispatchQueue.main.async {
                        guard let self, let camera, self.token == operation else { return }
                        do {
                            if error != nil { throw LibraryError.invalid("PTP identity request failed") }
                            // The framework may renumber wire transactions. The operation token
                            // above correlates this callback; wrapped data must match its response.
                            let wireTransaction = try PTPCallbackResponse.wireTransaction(in: response)
                            self.identity = try IdentityRequest.decode(data: data, response: response, expectedTransaction: wireTransaction)
                            self.finish(camera, message: "Identity read complete. Serial number discarded. Use the separate utility for recipe import.")
                        } catch { self.finish(camera, message: error.localizedDescription) }
                    }
                }
            }
        }
    }
    private func finish(_ camera: ICCameraDevice, message: String) {
        guard active === camera, !closing else { return }
        closing = true
        timeout?.cancel(); timeout = nil; token = nil
        status = message
        // Keep busy until close completes. If the framework never completes, no new command can start.
        camera.requestCloseSession(options: nil) { [weak self, weak camera] error in
            DispatchQueue.main.async {
                guard let self, let camera, self.active === camera else { return }
                if error != nil { self.status += " Session closure could not be confirmed. Reopen the inspector before another attempt."; return }
                camera.delegate = nil; self.active = nil; self.busy = false; self.closing = false
            }
        }
    }
    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        guard self.browser === browser, let camera = device as? ICCameraDevice, camera.usbVendorID == 0x04cb,
              !cameras.contains(where: { $0 === camera }) else { return }
        cameras.append(camera)
    }
    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        cameras.removeAll { $0 === device }
        if active === device { removed(device) }
    }
    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {}
    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {}
    func didRemove(_ device: ICDevice) { removed(device) }
    private func removed(_ device: ICDevice) {
        guard active === device else { return }
        timeout?.cancel(); timeout = nil; token = nil; active?.delegate = nil; active = nil; busy = false; closing = false
        status = "Camera disconnected. Inspection stopped."; identity = nil
    }
}
