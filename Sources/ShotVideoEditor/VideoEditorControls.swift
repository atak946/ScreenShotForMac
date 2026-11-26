import ShotCore
import SwiftUI

/// Play / pause, time, mute, speed, output format (+ GIF options), save mode and Save.
struct VideoEditorControls: View {
    @Bindable var model: VideoEditorModel
    let onSave: @MainActor () -> Void

    private static let gifFPSOptions = [10, 15, 20, 30]

    var body: some View {
        HStack(spacing: DS.Space.s) {
            playButton
            timeLabel
            Spacer(minLength: DS.Space.s)
            muteButton
            speedMenu
            ToolbarDivider()
            formatPicker
            if model.format == .gif { gifOptions }
            ToolbarDivider()
            saveModeMenu
            Button(String(localized: "Save", bundle: .module), action: onSave)
                .buttonStyle(PrimaryPillButtonStyle())
                .keyboardShortcut("s", modifiers: .command)
        }
        .frame(height: DS.Size.iconButtonLarge)
    }

    private var playButton: some View {
        Button(action: model.togglePlay) {
            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
        }
        .buttonStyle(ToolButtonStyle(size: DS.Size.iconButtonLarge))
        .keyboardShortcut(.space, modifiers: [])
        .help(model.isPlaying ? Text("Pause (Space)", bundle: .module) : Text("Play (Space)", bundle: .module))
    }

    private var timeLabel: some View {
        HStack(spacing: DS.Space.xs) {
            Text(VideoTimeFormat.string(model.currentTime - model.inPoint))
                .foregroundStyle(.primary)
            Text(verbatim: "/").foregroundStyle(.tertiary)
            Text(VideoTimeFormat.string(model.trimmedDuration))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium).monospacedDigit())
        .accessibilityElement(children: .combine)
    }

    private var muteButton: some View {
        Button { model.isMuted.toggle() } label: {
            Image(systemName: model.isMuted || !model.hasAudio ? "speaker.slash.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(ToolButtonStyle(isSelected: model.isMuted))
        .disabled(!model.hasAudio || model.format == .gif)
        .help(model.isMuted ? Text("Audio removed — click to keep audio", bundle: .module)
            : Text("Remove audio", bundle: .module))
    }

    private var speedMenu: some View {
        Picker(selection: $model.speed) {
            ForEach(PlaybackSpeed.allCases) { Text($0.title).tag($0) }
        } label: {
            Text("Speed", bundle: .module)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
        .help(Text("Playback and export speed", bundle: .module))
    }

    private var formatPicker: some View {
        Picker(selection: $model.format) {
            ForEach(VideoOutputFormat.allCases) { Text($0.title).tag($0) }
        } label: {
            Text("Format", bundle: .module)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private var gifOptions: some View {
        HStack(spacing: DS.Space.xs) {
            Picker(selection: $model.gifFramesPerSecond) {
                ForEach(Self.gifFPSOptions, id: \.self) { Text(verbatim: "\($0) fps").tag($0) }
            } label: {
                Text("Frame rate", bundle: .module)
            }
            .labelsHidden()
            .fixedSize()
            Picker(selection: $model.gifWidth) {
                ForEach(GIFWidth.allCases) { Text($0.title).tag($0) }
            } label: {
                Text("Width", bundle: .module)
            }
            .labelsHidden()
            .fixedSize()
        }
        .pickerStyle(.menu)
    }

    private var saveModeMenu: some View {
        Picker(selection: $model.saveMode) {
            ForEach(VideoSaveMode.allCases) { mode in
                Text(mode.title).tag(mode)
                    .selectionDisabled(mode == .overwrite && !model.canOverwrite)
            }
        } label: {
            Text("Save mode", bundle: .module)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }
}
