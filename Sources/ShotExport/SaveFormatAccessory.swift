import AppKit
import ShotCore

/// Accessory view for NSSavePanel with a PNG / JPEG / HEIC popup.
@MainActor
final class SaveFormatAccessory: NSObject {
    private weak var panel: NSSavePanel?
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private(set) var selectedFormat: ImageFormat

    let view: NSView

    init(panel: NSSavePanel, initial: ImageFormat) {
        self.panel = panel
        selectedFormat = initial
        view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 44))
        super.init()
        configure()
        apply(initial)
    }

    private func configure() {
        let label = NSTextField(labelWithString: String(localized: "Format:", bundle: .module))
        label.translatesAutoresizingMaskIntoConstraints = false
        popup.translatesAutoresizingMaskIntoConstraints = false
        for format in ImageFormat.allCases {
            popup.addItem(withTitle: format.rawValue.uppercased())
            popup.lastItem?.representedObject = format.rawValue
        }
        popup.selectItem(at: ImageFormat.allCases.firstIndex(of: selectedFormat) ?? 0)
        popup.target = self
        popup.action = #selector(formatChanged(_:))
        view.addSubview(label)
        view.addSubview(popup)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            popup.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            popup.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            popup.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
        ])
    }

    @objc
    private func formatChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let format = ImageFormat(rawValue: raw) else { return }
        apply(format)
    }

    private func apply(_ format: ImageFormat) {
        selectedFormat = format
        guard let panel else { return }
        panel.allowedContentTypes = [ImageEncoder.utType(for: format)]
        let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = base.isEmpty
            ? "\(FilenameTemplate.fallbackName).\(format.fileExtension)"
            : "\(base).\(format.fileExtension)"
    }
}
