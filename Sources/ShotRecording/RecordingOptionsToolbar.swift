import AppKit
import ShotCore

/// Per-recording switches chosen in the selection overlay.
struct RecordingToggles: Equatable, Sendable {
    var camera: Bool
    var microphone: Bool
    var systemAudio: Bool
    var clicks: Bool
    var keystrokes: Bool
}

/// Small glass toolbar shown during target selection: Camera, Mic, System audio,
/// Clicks and Keystrokes on / off. Floats above the selection overlay.
@MainActor
final class RecordingOptionsToolbar {
    private static let bottomInset: CGFloat = 72
    private static let height: CGFloat = DS.Size.toolbarHeight

    private(set) var toggles: RecordingToggles
    private let panel: NSPanel
    private var buttons: [Toggle: IconButton] = [:]
    private var targets: [ClosureActionTarget] = []

    private enum Toggle: CaseIterable {
        case camera, microphone, systemAudio, clicks, keystrokes
    }

    init(toggles: RecordingToggles, allowsAudio: Bool) {
        self.toggles = toggles
        panel = FloatingPanel.make(
            size: CGSize(width: 10, height: Self.height),
            level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        )
        let content = makeContent(allowsAudio: allowsAudio)
        let size = CGSize(width: ceil(content.fittingSize.width), height: Self.height)
        panel.setContentSize(size)
        content.frame = CGRect(origin: .zero, size: size)
        panel.contentView = content
        Toggle.allCases.forEach(refresh)
    }

    /// Bottom center of `screenFrame`.
    func show(on screenFrame: CGRect) {
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(
            x: (screenFrame.midX - size.width / 2).rounded(),
            y: screenFrame.minY + Self.bottomInset
        ))
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }

    // MARK: - Building

    private func makeContent(allowsAudio: Bool) -> NSView {
        let views = Toggle.allCases.map { toggle -> NSView in
            let target = ClosureActionTarget { [weak self] in self?.flip(toggle) }
            targets.append(target)
            let button = IconButton(
                symbol: "circle",
                tooltip: "",
                target: target,
                action: #selector(ClosureActionTarget.perform(_:))
            )
            button.isEnabled = isAvailable(toggle, allowsAudio: allowsAudio)
            buttons[toggle] = button
            return button
        }
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = DS.Space.xs
        stack.edgeInsets = NSEdgeInsets(top: 0, left: DS.Space.s, bottom: 0, right: DS.Space.s)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let surface = GlassSurfaceView(cornerRadius: Self.height / 2)
        surface.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            surface.heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: surface.contentView.centerYAnchor),
        ])
        return surface
    }

    private func isAvailable(_ toggle: Toggle, allowsAudio: Bool) -> Bool {
        switch toggle {
        case .microphone, .systemAudio: return allowsAudio
        case .keystrokes: return RecordingPermissions.isAccessibilityTrusted
        case .camera, .clicks: return true
        }
    }

    // MARK: - State

    private func flip(_ toggle: Toggle) {
        switch toggle {
        case .camera: toggles.camera.toggle()
        case .microphone: toggles.microphone.toggle()
        case .systemAudio: toggles.systemAudio.toggle()
        case .clicks: toggles.clicks.toggle()
        case .keystrokes: toggles.keystrokes.toggle()
        }
        refresh(toggle)
    }

    private func refresh(_ toggle: Toggle) {
        guard let button = buttons[toggle] else { return }
        let isOn = value(of: toggle)
        button.isSelectedState = isOn && button.isEnabled
        button.setSymbol(symbol(for: toggle, isOn: isOn), tooltip: tooltip(for: toggle, isOn: isOn, button: button))
    }

    private func value(of toggle: Toggle) -> Bool {
        switch toggle {
        case .camera: return toggles.camera
        case .microphone: return toggles.microphone
        case .systemAudio: return toggles.systemAudio
        case .clicks: return toggles.clicks
        case .keystrokes: return toggles.keystrokes
        }
    }

    private func symbol(for toggle: Toggle, isOn: Bool) -> String {
        switch toggle {
        case .camera: return isOn ? "video.fill" : "video.slash"
        case .microphone: return isOn ? "mic.fill" : "mic.slash"
        case .systemAudio: return isOn ? "speaker.wave.2.fill" : "speaker.slash"
        case .clicks: return "cursorarrow.click.2"
        case .keystrokes: return "keyboard"
        }
    }

    private func tooltip(for toggle: Toggle, isOn: Bool, button: IconButton) -> String {
        if toggle == .keystrokes, !button.isEnabled { return RecordingPermissions.accessibilityHint }
        if !button.isEnabled {
            return String(localized: "Audio is not available for GIF recordings", bundle: .module)
        }
        switch toggle {
        case .camera:
            return isOn ? String(localized: "Camera: On", bundle: .module) : String(localized: "Camera: Off", bundle: .module)
        case .microphone:
            return isOn ? String(localized: "Microphone: On", bundle: .module) : String(localized: "Microphone: Off", bundle: .module)
        case .systemAudio:
            return isOn ? String(localized: "System Audio: On", bundle: .module) : String(localized: "System Audio: Off", bundle: .module)
        case .clicks:
            return isOn ? String(localized: "Highlight Clicks: On", bundle: .module) : String(
                localized: "Highlight Clicks: Off",
                bundle: .module
            )
        case .keystrokes:
            return isOn ? String(localized: "Show Keystrokes: On", bundle: .module) : String(
                localized: "Show Keystrokes: Off",
                bundle: .module
            )
        }
    }
}
