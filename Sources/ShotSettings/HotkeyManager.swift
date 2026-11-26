import AppKit
import KeyboardShortcuts
import ShotCore
import SwiftUI

/// Registers global hotkeys and forwards them to the command handler.
@MainActor
public final class HotkeyManager {
    private weak var handler: CommandHandling?
    private var isStarted = false

    public init(handler: CommandHandling) {
        self.handler = handler
    }

    /// Registers key-up listeners for every hotkey command. Safe to call more than once.
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        for command in HotkeyRegistry.hotkeyCommands {
            guard let name = HotkeyRegistry.name(for: command) else { continue }
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                MainActor.assumeIsolated {
                    self?.fire(command)
                }
            }
        }
        Log.settings.info("Registered \(HotkeyRegistry.hotkeyCommands.count) global hotkeys")
    }

    /// Temporarily disables all global hotkeys (e.g. while a menu is open).
    public func setHotkeysEnabled(_ enabled: Bool) {
        let names = HotkeyRegistry.allNames
        if enabled {
            KeyboardShortcuts.enable(names)
        } else {
            KeyboardShortcuts.disable(names)
        }
    }

    /// Human-readable shortcut, e.g. "⌥⇧1". Nil when unassigned.
    public func shortcutDescription(for command: AppCommand) -> String? {
        Self.shortcutDescription(for: command)
    }

    /// Key equivalent suitable for `NSMenuItem.keyEquivalent` / `keyEquivalentModifierMask`.
    public func keyEquivalent(for command: AppCommand) -> (String, NSEvent.ModifierFlags)? {
        Self.keyEquivalent(for: command)
    }

    /// Applies the current shortcut of the command to a menu item (or clears it).
    public func applyShortcut(for command: AppCommand, to item: NSMenuItem) {
        item.setShortcut(for: HotkeyRegistry.name(for: command))
    }

    public static func shortcutDescription(for command: AppCommand) -> String? {
        guard let shortcut = HotkeyRegistry.name(for: command)?.shortcut else { return nil }
        return shortcut.description
    }

    public static func keyEquivalent(for command: AppCommand) -> (String, NSEvent.ModifierFlags)? {
        guard
            let shortcut = HotkeyRegistry.name(for: command)?.shortcut,
            let key = shortcut.nsMenuItemKeyEquivalent
        else { return nil }
        return (key, shortcut.modifiers)
    }

    private func fire(_ command: AppCommand) {
        guard let handler else {
            Log.settings.error("Hotkey for \(command.rawValue) fired without a handler")
            return
        }
        handler.perform(command)
    }
}

extension View {
    /// Shows the command's global hotkey next to a `Button` in a `Menu` / `MenuBarExtra`.
    /// Does not trigger the action itself; the global hotkey does.
    @ViewBuilder
    public func commandShortcutHint(_ command: AppCommand) -> some View {
        if let name = HotkeyRegistry.name(for: command) {
            globalKeyboardShortcut(name)
        } else {
            self
        }
    }
}
