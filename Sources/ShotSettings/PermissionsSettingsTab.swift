import ApplicationServices
import CoreGraphics
import ShotCore
import SwiftUI

struct PermissionsSettingsTab: View {
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var microphone = MicrophonePermission()

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: String(localized: "Screen Recording", bundle: .module),
                    detail: String(localized: "Required to capture screenshots of your displays and windows.", bundle: .module),
                    symbol: "rectangle.dashed.badge.record",
                    color: .indigo,
                    isGranted: hasScreenRecording,
                    actionTitle: String(localized: "Open System Settings", bundle: .module),
                    action: requestScreenRecording
                )
                if !hasScreenRecording {
                    LabeledContent {
                        Button(String(localized: "Quit & Reopen", bundle: .module)) { AppRelauncher.relaunch() }
                    } label: {
                        Text("Already allowed? macOS applies it after a restart.", bundle: .module)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Required", bundle: .module)
            } footer: {
                SettingsFooter(text: String(
                    localized: "After granting Screen Recording, macOS may ask you to quit and reopen the app.",
                    bundle: .module
                ))
            }
            Section {
                PermissionRow(
                    title: String(localized: "Accessibility", bundle: .module),
                    detail: String(localized: "Optional. Used for window detection and advanced capture features.", bundle: .module),
                    symbol: "accessibility",
                    color: .blue,
                    isGranted: hasAccessibility,
                    actionTitle: String(localized: "Open System Settings", bundle: .module),
                    action: { SystemSettingsLink.accessibility.open() }
                )
                PermissionRow(
                    title: String(localized: "Microphone", bundle: .module),
                    detail: String(localized: "Optional. Only needed to record your voice with screen recordings.", bundle: .module),
                    symbol: "mic.fill",
                    color: .orange,
                    isGranted: microphone.isGranted,
                    actionTitle: microphone.canRequest
                        ? String(localized: "Allow…", bundle: .module)
                        : String(localized: "Open System Settings", bundle: .module),
                    action: requestMicrophone
                )
            } header: {
                Text("Optional", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        hasScreenRecording = CGPreflightScreenCaptureAccess()
        hasAccessibility = AXIsProcessTrusted()
        microphone.refresh()
    }

    /// Registers the app in the Screen Recording list (system prompt), then opens the pane.
    private func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            SystemSettingsLink.screenRecording.open()
        }
        refresh()
    }

    private func requestMicrophone() {
        guard microphone.canRequest else {
            SystemSettingsLink.microphone.open()
            return
        }
        Task { await microphone.request() }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: DS.Space.s) {
                if !isGranted {
                    Button(actionTitle, action: action)
                }
                StatusBadge(isGranted: isGranted)
            }
        } label: {
            SettingsRowLabel(title: title, symbol: symbol, color: color, subtitle: detail)
        }
        .padding(.vertical, DS.Space.xxs)
    }
}
