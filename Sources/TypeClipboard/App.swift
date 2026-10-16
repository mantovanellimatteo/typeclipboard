import AppKit
import SwiftUI

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // solo barra dei menu, niente Dock
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let hotKey = HotKeyManager()
    private let typer = Typer()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        hotKey.handler = { [weak self] in self?.typeClipboard() }
        settings.onHotKeyChange = { [weak self] in
            self?.registerHotKey()
            self?.buildMenu()
        }
        typer.onStateChange = { [weak self] in
            self?.updateStatusIcon()
            self?.buildMenu()
        }
        registerHotKey()
        buildMenu()

        // Esc interrompe una digitazione in corso
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.typer.cancel() }
        }

        if !Accessibility.isTrusted(prompt: true) {
            openSettings()
        }
    }

    private func updateStatusIcon() {
        let symbol = typer.isTyping ? "keyboard.badge.ellipsis" : "keyboard"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "TypeClipboard")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    private func registerHotKey() {
        if !hotKey.register(keyCode: settings.keyCode, modifiers: settings.modifiers) {
            let alert = NSAlert()
            alert.messageText = "Scorciatoia non disponibile"
            alert.informativeText = "\(settings.shortcutDescription) è già usata da un'altra app. Scegline un'altra nelle impostazioni."
            alert.runModal()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.minimumWidth = 280

        // Header card in stile Liquid Glass con anteprima clipboard
        let headerItem = NSMenuItem()
        let clipText = NSPasteboard.general.string(forType: .string) ?? ""
        let headerView = NSHostingView(
            rootView: MenuHeaderCard(
                clipboardText: clipText,
                shortcut: settings.shortcutDescription,
                isTyping: typer.isTyping,
                progress: typer.progress
            )
        )
        headerView.frame = NSRect(x: 0, y: 0, width: 280, height: 84)
        headerItem.view = headerView
        menu.addItem(headerItem)
        menu.addItem(.separator())

        // Azione principale: Digita clipboard
        let typeItem = item(
            "Digita clipboard",
            #selector(typeClipboardFromMenu),
            symbol: "bolt.horizontal.fill"
        )
        applyShortcutDisplay(to: typeItem)
        if !clipText.isEmpty, #available(macOS 14.0, *) {
            typeItem.badge = NSMenuItemBadge(string: "\(clipText.count) car.")
        }
        typeItem.isEnabled = !clipText.isEmpty && !typer.isTyping
        menu.addItem(typeItem)

        // Interrompi digitazione
        let stopItem = item(
            typer.isTyping ? "Interrompi digitazione in corso" : "Interrompi digitazione",
            #selector(stopTyping),
            symbol: "stop.circle.fill"
        )
        stopItem.keyEquivalent = "\u{1b}"
        stopItem.keyEquivalentModifierMask = []
        stopItem.isEnabled = typer.isTyping
        menu.addItem(stopItem)

        menu.addItem(.separator())

        // Stato permesso Accessibilità se mancante
        if !Accessibility.isTrusted(prompt: false) {
            let warnItem = item(
                "Abilita permesso Accessibilità…",
                #selector(openAccessibilitySettings),
                symbol: "exclamationmark.shield.fill"
            )
            menu.addItem(warnItem)
            menu.addItem(.separator())
        }

        let prefsItem = item("Impostazioni…", #selector(openSettings), key: ",", symbol: "slider.horizontal.3")
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let quitItem = item("Esci da TypeClipboard", #selector(quit), key: "q", symbol: "power")
        if #available(macOS 14.4, *) {
            quitItem.subtitle = "Versione \(version)"
        }
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        if let symbol, let img = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(textStyle: .body, scale: .medium)
            i.image = img.withSymbolConfiguration(config)
            if #available(macOS 27.0, *) {
                i.preferredImageVisibility = .visible
            }
        }
        return i
    }

    private func applyShortcutDisplay(to menuItem: NSMenuItem) {
        let keyName = KeyboardLayoutMapper.keyName(for: settings.keyCode)
        if keyName.count == 1 {
            menuItem.keyEquivalent = keyName.lowercased()
            menuItem.keyEquivalentModifierMask = settings.modifiers
        } else if #available(macOS 14.4, *) {
            menuItem.subtitle = "Scorciatoia: \(settings.shortcutDescription)"
        }
    }

    @objc private func typeClipboardFromMenu() {
        // lascia chiudere il menu e tornare il focus all'app precedente
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.typeClipboard() }
    }

    @objc private func openAccessibilitySettings() {
        Accessibility.openSystemSettings()
    }

    private func typeClipboard() {
        guard Accessibility.isTrusted(prompt: true) else {
            openSettings()
            return
        }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep()
            return
        }
        typer.type(text, keyDelayMs: settings.keyDelayMs, initialDelayMs: settings.initialDelayMs)
    }

    @objc private func stopTyping() { typer.cancel() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings, typer: typer))
            let w = NSWindow(contentViewController: hosting)
            w.title = "TypeClipboard"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

enum Accessibility {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
