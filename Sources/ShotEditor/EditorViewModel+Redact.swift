import AppKit
import ShotCore

/// What Auto Redact looks for and how it hides it.
struct RedactOptions: Equatable, Sendable {
    /// `.blur` or `.pixelate`.
    var style: EditorTool = .blur
    var kinds: Set<SensitiveKind> = Set(SensitiveKind.allCases)
}

/// Short message shown in a glass toast over the canvas.
struct EditorToast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let symbol: String
}

extension SensitiveKind {
    var displayName: String {
        switch self {
        case .email: return String(localized: "Email Addresses", bundle: .module)
        case .phone: return String(localized: "Phone Numbers", bundle: .module)
        case .creditCard: return String(localized: "Credit Cards", bundle: .module)
        case .iban: return String(localized: "IBANs", bundle: .module)
        case .ipAddress: return String(localized: "IP Addresses", bundle: .module)
        case .url: return String(localized: "URLs", bundle: .module)
        case .apiKey: return String(localized: "API Keys & Tokens", bundle: .module)
        case .jwt: return String(localized: "JSON Web Tokens", bundle: .module)
        }
    }
}

extension EditorViewModel {
    private static let toastDuration: Duration = .seconds(2.2)

    var canAutoRedact: Bool { sensitiveDataDetector != nil }

    /// Scans the base image and covers every finding with one blur / pixelate annotation,
    /// registered as a single undo step.
    func autoRedact() {
        guard let detector = sensitiveDataDetector, !isRedacting else { return }
        let options = redactOptions
        guard !options.kinds.isEmpty else {
            showToast(String(localized: "Choose at least one kind of data", bundle: .module), symbol: "exclamationmark.triangle")
            return
        }
        beforeExport?()
        let image = document.baseImage
        isRedacting = true
        Task { [weak self] in
            do {
                let regions = try await detector.detect(in: image, kinds: options.kinds)
                self?.finishRedaction(regions, options: options, sourceImage: image)
            } catch {
                Log.editor.error("Auto Redact failed: \(error.localizedDescription, privacy: .public)")
                self?.isRedacting = false
                self?.showToast(String(localized: "Auto Redact failed", bundle: .module), symbol: "exclamationmark.triangle")
            }
        }
    }

    private func finishRedaction(_ regions: [SensitiveRegion], options: RedactOptions, sourceImage: CGImage) {
        isRedacting = false
        // A rotation during the scan invalidates the pixel rects.
        guard document.baseImage === sourceImage else {
            Log.editor.debug("Auto Redact discarded: base image changed during scan")
            return
        }
        let annotations = redactionAnnotations(for: regions, options: options)
        guard !annotations.isEmpty else {
            showToast(String(localized: "Nothing sensitive found", bundle: .module), symbol: "checkmark.shield")
            return
        }
        if tool == .crop { selectTool(.select) }
        apply(String(localized: "Auto Redact", bundle: .module)) { $0.adding(annotations) }
        selectedIDs = Set(annotations.map(\.id))
        showToast(String(localized: "Redacted \(annotations.count) items", bundle: .module), symbol: "eye.slash")
    }

    private func redactionAnnotations(for regions: [SensitiveRegion], options: RedactOptions) -> [Annotation] {
        let kind: AnnotationKind = options.style == .pixelate ? .pixelate : .blur
        let scale = document.scale
        let output = document.outputRect
        let rects = regions.map { region in
            CGRect(
                x: region.pixelRect.minX / scale, y: region.pixelRect.minY / scale,
                width: region.pixelRect.width / scale, height: region.pixelRect.height / scale
            )
        }
        return rects
            .filter { $0.intersects(output) && !alreadyRedacted($0) }
            .map { Annotation(kind: kind, start: $0.origin, end: CGPoint(x: $0.maxX, y: $0.maxY), style: style) }
    }

    /// Skips findings already fully covered by an existing blur / pixelate (re-running is idempotent).
    private func alreadyRedacted(_ rect: CGRect) -> Bool {
        document.annotations.contains { annotation in
            (annotation.kind == .blur || annotation.kind == .pixelate) && annotation.rect.contains(rect)
        }
    }

    func showToast(_ message: String, symbol: String) {
        toastTask?.cancel()
        let toast = EditorToast(message: message, symbol: symbol)
        self.toast = toast
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.toastDuration)
            guard !Task.isCancelled, self?.toast == toast else { return }
            self?.toast = nil
        }
    }

    func setRedactKind(_ kind: SensitiveKind, enabled: Bool) {
        var options = redactOptions
        if enabled { options.kinds.insert(kind) } else { options.kinds.remove(kind) }
        redactOptions = options
    }

    func setRedactStyle(_ style: EditorTool) {
        guard style == .blur || style == .pixelate else { return }
        var options = redactOptions
        options.style = style
        redactOptions = options
    }
}
