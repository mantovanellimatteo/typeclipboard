import AppKit
import ServiceManagement
import SwiftUI

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard
    var onHotKeyChange: (() -> Void)?

    @Published private(set) var keyCode: UInt32
    @Published private(set) var modifiersRaw: UInt
    @Published var keyDelayMs: Int { didSet { d.set(keyDelayMs, forKey: "keyDelayMs") } }
    @Published var initialDelayMs: Int { didSet { d.set(initialDelayMs, forKey: "initialDelayMs") } }

    private init() {
        d.register(defaults: [
            "keyCode": 9, // V
            "modifiers": NSEvent.ModifierFlags([.control, .option]).rawValue,
            "keyDelayMs": 10,
            "initialDelayMs": 300,
        ])
        keyCode = UInt32(d.integer(forKey: "keyCode"))
        modifiersRaw = UInt(bitPattern: d.integer(forKey: "modifiers"))
        keyDelayMs = d.integer(forKey: "keyDelayMs")
        initialDelayMs = d.integer(forKey: "initialDelayMs")
    }

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiersRaw) }

    func setHotKey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRaw = modifiers.rawValue
        d.set(Int(keyCode), forKey: "keyCode")
        d.set(Int(bitPattern: modifiers.rawValue), forKey: "modifiers")
        onHotKeyChange?()
    }

    var shortcutDescription: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + KeyboardLayoutMapper.keyName(for: keyCode)
    }
}

/// Stato UI (niente @State: la sua macro non è disponibile con i soli Command Line Tools).
final class SettingsUIState: ObservableObject {
    @Published var trusted = Accessibility.isTrusted(prompt: false)
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do { launchAtLogin ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
            catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @StateObject private var ui = SettingsUIState()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var trusted: Bool { ui.trusted }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: trusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Permesso Accessibilità concesso" : "Serve il permesso Accessibilità")
                    Spacer()
                    if !trusted { Button("Apri Impostazioni") { Accessibility.openSystemSettings() } }
                }
            }
            Section("Scorciatoia") {
                LabeledContent("Digita clipboard") { ShortcutRecorder(settings: settings) }
            }
            Section("Digitazione") {
                Stepper(value: $settings.keyDelayMs, in: 0...500, step: 5) {
                    LabeledContent("Ritardo tra i tasti", value: "\(settings.keyDelayMs) ms")
                }
                Stepper(value: $settings.initialDelayMs, in: 0...5000, step: 100) {
                    LabeledContent("Ritardo iniziale", value: "\(settings.initialDelayMs) ms")
                }
                Text("Aumenta il ritardo tra i tasti se la console remota perde caratteri. Premi Esc per interrompere.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Avvia al login", isOn: $ui.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
        .onReceive(timer) { _ in ui.trusted = Accessibility.isTrusted(prompt: false) }
    }
}

struct ShortcutRecorder: View {
    @ObservedObject var settings: Settings
    @StateObject private var recorder = Recorder()

    var body: some View {
        Button(recorder.recording ? "Premi la combinazione… (Esc annulla)" : settings.shortcutDescription) {
            recorder.recording ? recorder.stop() : recorder.start(settings)
        }
        .monospaced()
    }
}

final class Recorder: ObservableObject {
    @Published var recording = false
    private var monitor: Any?

    func start(_ settings: Settings) {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.stop(); return nil }
            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard !mods.intersection([.command, .control, .option]).isEmpty else {
                NSSound.beep() // serve almeno ⌘, ⌃ o ⌥
                return nil
            }
            settings.setHotKey(keyCode: UInt32(event.keyCode), modifiers: mods)
            self?.stop()
            return nil
        }
    }

    func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
