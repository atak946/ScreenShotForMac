import ShotCore
import SwiftUI

/// Three-step first-run flow: welcome, screen recording permission, shortcuts.
public struct OnboardingView: View {
    public static let size = CGSize(width: 560, height: 460)

    private let onFinish: @MainActor () -> Void
    private let requestScreenPermission: @MainActor () -> Void
    private let hasScreenPermission: @MainActor () -> Bool

    @State private var step: Step = .welcome
    @State private var isMovingForward = true

    public init(
        onFinish: @escaping @MainActor () -> Void,
        requestScreenPermission: @escaping @MainActor () -> Void,
        hasScreenPermission: @escaping @MainActor () -> Bool
    ) {
        self.onFinish = onFinish
        self.requestScreenPermission = requestScreenPermission
        self.hasScreenPermission = hasScreenPermission
    }

    enum Step: Int, CaseIterable {
        case welcome, permission, shortcuts
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                content
                    .id(step)
                    .transition(stepTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, DS.Space.xxl + DS.Space.s)
            .padding(.top, DS.Space.xxl + DS.Space.s)
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(backdrop)
        .animation(DS.Motion.spring, value: step)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep()
        case .permission:
            OnboardingPermissionStep(request: requestScreenPermission, isGranted: hasScreenPermission)
        case .shortcuts:
            OnboardingShortcutsStep()
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var backdrop: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Color.accentColor.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    private var footer: some View {
        HStack(spacing: DS.Space.s) {
            OnboardingPageDots(current: step.rawValue, count: Step.allCases.count)
            Spacer()
            if step != .welcome {
                Button(String(localized: "Back", bundle: .module)) { move(by: -1) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
            }
            Button(isLastStep ? String(localized: "Get Started", bundle: .module) : String(localized: "Continue", bundle: .module)) {
                isLastStep ? finish() : move(by: 1)
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.l)
    }

    private var isLastStep: Bool { step == Step.allCases.last }

    private func move(by offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        isMovingForward = offset > 0
        step = next
    }

    private func finish() {
        AppSettings.shared.hasCompletedOnboarding = true
        Log.settings.info("Onboarding completed")
        onFinish()
    }
}
