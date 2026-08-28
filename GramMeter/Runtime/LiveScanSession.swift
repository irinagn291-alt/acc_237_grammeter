import AVFoundation
import SwiftUI

/// AVCaptureMetadataOutput live session. Confined start/stop to a private queue.
/// @unchecked Sendable: `session` is only touched on `queue`.
final class LiveScanSession: NSObject, @unchecked Sendable {
    var onCode: (@MainActor (String) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "grammeter.scan")
    private var lastPayload: String?
    private var lastAt = Date.distantPast
    private var configured = false

    var hasDevice: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    func requestAccess(result: @escaping @MainActor (ScanPermission) -> Void) {
        if !hasDevice {
            Task { @MainActor in result(.missingDevice) }
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Task { @MainActor in result(.allowed) }
        case .denied:
            Task { @MainActor in result(.denied) }
        case .restricted:
            Task { @MainActor in result(.restricted) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    result(granted ? .allowed : .denied)
                }
            }
        @unknown default:
            Task { @MainActor in result(.denied) }
        }
    }

    func start() {
        queue.async { [weak self] in
            self?.configureIfNeeded()
            guard let self, self.session.inputs.isEmpty == false else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func previewSession() -> AVCaptureSession {
        session
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: queue)
            let wanted: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .qr]
            output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
        }
        session.commitConfiguration()
    }
}

extension LiveScanSession: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let raw = first.stringValue,
              !raw.isEmpty else { return }
        let now = Date()
        if raw == lastPayload && now.timeIntervalSince(lastAt) < 1.8 { return }
        lastPayload = raw
        lastAt = now
        let callback = onCode
        Task { @MainActor in
            callback?(raw)
        }
    }
}

struct ScanPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.preview.session = session
    }

    final class PreviewSurface: UIView {
        let preview = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            preview.frame = bounds
            layer.addSublayer(preview)
        }

        required init?(coder: NSCoder) {
            return nil
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            preview.frame = bounds
        }
    }
}
