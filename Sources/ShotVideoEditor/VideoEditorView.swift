import ShotCore
import SwiftUI

/// Actions the window controller handles for the editor view.
struct VideoEditorActions {
    let save: @MainActor () -> Void
    let cancelExport: @MainActor () -> Void
    let close: @MainActor () -> Void
}

/// Full-bleed preview with a floating glass bottom bar (timeline + controls).
struct VideoEditorView: View {
    let model: VideoEditorModel
    let actions: VideoEditorActions
    @Binding var errorMessage: String?

    private static let barInset: CGFloat = DS.Space.m
    private static let reservedBarHeight: CGFloat = 132

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            content
            if model.phase == .ready || model.isExporting {
                bottomBar
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .task { await model.load() }
        .alert(
            Text("Export Failed", bundle: .module),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            actions: { Button(String(localized: "OK", bundle: .module)) { errorMessage = nil } },
            message: { Text(errorMessage ?? "") }
        )
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            failure(message)
        case .ready, .exporting:
            PlayerSurface(player: model.player)
                .padding(.top, DS.Space.xxl)
                .padding(.bottom, Self.reservedBarHeight)
                .onTapGesture { model.togglePlay() }
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: DS.Space.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
            Text(message).foregroundStyle(.white)
            Button(String(localized: "Close", bundle: .module), action: actions.close)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        VStack(spacing: DS.Space.m) {
            FilmstripTimeline(model: model)
                .disabled(model.isExporting)
            if case let .exporting(progress) = model.phase {
                ExportProgressRow(progress: progress, onCancel: actions.cancelExport)
            } else {
                VideoEditorControls(model: model, onSave: actions.save)
            }
        }
        .padding(DS.Space.m)
        .glassSurface(cornerRadius: DS.Radius.panel)
        .padding(Self.barInset)
    }
}

/// Progress bar shown in place of the controls while exporting.
private struct ExportProgressRow: View {
    let progress: Double
    let onCancel: @MainActor () -> Void

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Text("Exporting…", bundle: .module)
                .font(.system(size: 13, weight: .medium))
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            Button(String(localized: "Cancel", bundle: .module), action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .frame(height: DS.Size.iconButtonLarge)
    }
}
