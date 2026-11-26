import Foundation
import Darwin
@preconcurrency import ImageCaptureCore
import RecipeCore

struct WireReply { let data: Data; let response: Data }

/// Manual developer utility. It never runs as part of the app or automated tests.
@MainActor
final class ImportDriver: NSObject, ICDeviceBrowserDelegate, ICDeviceDelegate {
    private let browser = ICDeviceBrowser()
    private let output: URL
    private var cameras: [ICCameraDevice] = []
    private var camera: ICCameraDevice?
    private var pending: ((Result<WireReply, Error>) -> Void)?
    private var deadline: DispatchWorkItem?
    private var generation = UUID()
    private var transaction: UInt32 = 0
    private var usable = true
    private var started = false
    private var closing = false
    init(output: URL) { self.output = output; super.init() }

    func start() {
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue)!
        print("Scanning for one local Fujifilm camera. No recipe-setting writes are available.")
        browser.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
            guard !started else { return }
            guard cameras.count == 1 else { finish("Expected one Fujifilm USB camera; found \(cameras.count). No session opened.", code: 1); return }
            started = true; camera = cameras[0]; camera?.delegate = self
            Task { await run() }
        }
    }
    private func perform(_ call: (@escaping (Result<WireReply, Error>) -> Void) -> Void) async throws -> WireReply {
        guard pending == nil else { throw CameraImportError.invalid("A camera request is already pending") }
        let id = UUID(); generation = id
        return try await withCheckedThrowingContinuation { continuation in
            pending = { continuation.resume(with: $0) }
            let timer = DispatchWorkItem { [self] in
                guard generation == id, let callback = pending else { return }
                usable = false; pending = nil
                callback(.failure(CameraImportError.invalid("Camera request timed out; no further property commands will be sent")))
            }
            deadline = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timer)
            call { result in
                DispatchQueue.main.async { [self] in
                    guard generation == id, let callback = pending else { return }
                    deadline?.cancel(); deadline = nil; pending = nil
                    callback(result)
                }
            }
        }
    }
    private func send(_ command: BankImportCommand) async throws -> WireReply {
        guard usable, let camera else { throw CameraImportError.invalid("Camera transport is no longer usable") }
        transaction += 1
        let encoded = try command.encoded(transaction: transaction)
        return try await perform { callback in
            camera.requestSendPTPCommand(encoded.command, outData: encoded.outData) { data, response, error in
                if let error { callback(.failure(error)) }
                else { callback(.success(WireReply(data: data, response: response))) }
            }
        }
    }
    private func exchange(_ command: BankImportCommand) async throws -> Data {
        let reply: WireReply
        do { reply = try await send(command) }
        catch { usable = false; throw error }
        do { return try command.payload(data: reply.data, response: reply.response, transaction: try PTPCallbackResponse.wireTransaction(in: reply.response)) }
        catch CameraImportError.response(let code) {
            if [UInt16(0x2003), 0x2004, 0x201E].contains(code) { usable = false }
            throw CameraImportError.response(code)
        }
        catch { usable = false; throw error }
    }
    private func run() async {
        guard let camera else { return }
        guard !camera.hasOpenSession else { finish("Camera session already open. Close other camera apps.", code: 1); return }
        guard camera.capabilities.contains(ICDeviceCapability.cameraDeviceCanAcceptPTPCommands.rawValue) else {
            finish("PTP pass-through is not available in this mode.", code: 1); return
        }
        var failure: Error?
        var document: RecipeDocument?
        do {
            _ = try await perform { callback in
                camera.requestOpenSession(options: nil) { error in
                    if let error { callback(.failure(error)) }
                    else { callback(.success(WireReply(data: Data(), response: Data()))) }
                }
            }
            let identityReply = try await send(.identity)
            let wireTransaction = try PTPCallbackResponse.wireTransaction(in: identityReply.response)
            let identity = try IdentityRequest.decode(data: identityReply.data, response: identityReply.response, expectedTransaction: wireTransaction)
            print("Camera: \(identity.model); firmware: \(identity.firmware). Serial discarded.")
            let banks = try await CameraBankReader.read(identity: identity) { [self] command in
                if case .select(let bank) = command { print("Selecting bank C\(bank) for reading or original-selector restoration.") }
                return try await exchange(command)
            }
            document = try CameraRecipeDocument.make(identity: identity, banks: banks)
            print("Read C1–C4; original selector restored and verified.")
        } catch { failure = error }
        closing = true
        do {
            _ = try await perform { callback in
                camera.requestCloseSession(options: nil) { error in
                    if let error { callback(.failure(error)) }
                    else { callback(.success(WireReply(data: Data(), response: Data()))) }
                }
            }
        } catch { finish("Session closure UNCONFIRMED. \(failure?.localizedDescription ?? "") \(error.localizedDescription)", code: 1); return }
        if let failure { finish(failure.localizedDescription, code: 1); return }
        do {
            guard let document else { throw CameraImportError.invalid("No complete import document") }
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try document.encoded().write(to: output, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
            finish("Saved \(document.recipes.count) recipes: \(output.path)", code: 0)
        } catch { finish("Camera reading finished, but export failed: \(error.localizedDescription)", code: 1) }
    }
    private func finish(_ message: String, code: Int32) {
        print(message); browser.stop(); exit(code)
    }
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        DispatchQueue.main.async { [self] in
            guard !started, let camera = device as? ICCameraDevice, camera.usbVendorID == 0x04CB else { return }
            if !cameras.contains(where: { $0 === camera }) { cameras.append(camera) }
        }
    }
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        DispatchQueue.main.async { [self] in
            cameras.removeAll { $0 === device }
            if camera === device { handleRemoval(device) }
        }
    }
    nonisolated func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {}
    nonisolated func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        DispatchQueue.main.async { [self] in
            if !closing { handleRemoval(device) }
        }
    }
    nonisolated func didRemove(_ device: ICDevice) {
        DispatchQueue.main.async { [self] in handleRemoval(device) }
    }
    private func handleRemoval(_ device: ICDevice) {
        guard camera === device else { return }
        usable = false; deadline?.cancel(); deadline = nil
        if let callback = pending { pending = nil; callback(.failure(CameraImportError.invalid("Camera disconnected; selector restoration may be unconfirmed"))) }
    }
}

umask(0o077) // Camera exports and their new directories are private to this user.
let arguments = CommandLine.arguments
if arguments.count != 4 || arguments[1] != "--backup-confirmed" || arguments[2] != "--output" {
    print("Usage: RecipeCameraImport --backup-confirmed --output /absolute/path/Recipes.json")
    print("Requires an untouched official backup and X-M5 firmware 1.30 in USB RAW CONV./BACKUP RESTORE mode.")
    exit(2)
}
guard arguments[3].hasPrefix("/"), !FileManager.default.fileExists(atPath: arguments[3]) else {
    print("Choose a new absolute output path. Existing files will not be overwritten."); exit(2)
}
DispatchQueue.main.async {
    let driver = ImportDriver(output: URL(fileURLWithPath: arguments[3]))
    driver.start()
}
RunLoop.main.run()
