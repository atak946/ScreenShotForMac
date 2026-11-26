import AppKit
import ShotCore
import SwiftUI

/// Small glass capsule near the top of the canvas showing `EditorViewModel.toast`.
struct EditorToastView: View {
    private static let hiddenOffset: CGFloat = -8

    let viewModel: EditorViewModel

    var body: some View {
        ZStack {
            if let toast = viewModel.toast {
                Label(toast.message, systemImage: toast.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, DS.Space.m)
                    .padding(.vertical, DS.Space.s - 2)
                    .glassSurface(cornerRadius: DS.Size.iconButton / 2)
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
                    .transition(.opacity.combined(with: .offset(y: Self.hiddenOffset)))
                    .id(toast.id)
            }
        }
        .fixedSize()
        .animation(DS.Motion.spring, value: viewModel.toast)
        .allowsHitTesting(false)
    }
}

/// Hosting view that never takes mouse events, so the canvas below keeps working.
@MainActor
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
