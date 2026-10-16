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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let hotKey = HotKeyManager()
    private let typer = Typer()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "TypeClipboard")

        hotKey.handler = { [weak self] in self?.typeClipboard() }
        settings.onHotKeyChange = { [weak self] in
            self?.registerHotKey()
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

    private func registerHotKey() {
        if !hotKey.register(keyCode: settings.keyCode, modifiers: settings.modifiers) {
            let alert = NSAlert()
            alert.messageText = "Scorciatoia non disponibile"
            alert.informativeText = "\(settings.shortcutDescription) è già usata da un'altra app. Scegline un'altra nelle impostazioni."
            alert.runModal()
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(item("Digita clipboard  (\(settings.shortcutDescription))", #selector(typeClipboardFromMenu)))
        menu.addItem(item("Interrompi digitazione  (Esc)", #selector(stopTyping)))
        menu.addItem(.separator())
        menu.addItem(item("Impostazioni…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Esci da TypeClipboard", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func typeClipboardFromMenu() {
        // lascia chiudere il menu e tornare il focus all'app precedente
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.typeClipboard() }
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
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            w.title = "Impostazioni TypeClipboard"
            w.styleMask = [.titled, .closable]
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
