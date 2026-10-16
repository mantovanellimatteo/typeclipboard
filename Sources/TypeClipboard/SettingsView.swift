import AppKit
import Combine
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

    var shortcutSymbols: [String] {
        var list: [String] = []
        if modifiers.contains(.control) { list.append("⌃") }
        if modifiers.contains(.option) { list.append("⌥") }
        if modifiers.contains(.shift) { list.append("⇧") }
        if modifiers.contains(.command) { list.append("⌘") }
        list.append(KeyboardLayoutMapper.keyName(for: keyCode))
        return list
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

// MARK: - Liquid Glass Helpers (macOS Tahoe 26+ con fallback Material)

extension View {
    @ViewBuilder
    func liquidGlassCard(cornerRadius: CGFloat = 18, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(
                (tint != nil ? Glass.regular.tint(tint) : Glass.regular).interactive(interactive),
                in: shape
            )
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                )
        }
    }

    @ViewBuilder
    func liquidGlassPill(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(
                (tint != nil ? Glass.regular.tint(tint) : Glass.regular).interactive(interactive),
                in: Capsule()
            )
        } else {
            self.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.8))
        }
    }
}

/// Sfondo finestra traslucido integrato con il desktop.
struct WindowBlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Menu Header Card (Barra dei menu)

struct MenuHeaderCard: View {
    let clipboardText: String
    let shortcut: String
    let isTyping: Bool
    let progress: (current: Int, total: Int)

    private var previewText: String {
        let trimmed = clipboardText
            .replacingOccurrences(of: "\r\n", with: " ↵ ")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Appunti vuoti" }
        return trimmed.count > 48 ? String(trimmed.prefix(48)) + "…" : trimmed
    }

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isTyping
                                ? [Color.orange, Color.pink]
                                : [Color.cyan.opacity(0.85), Color.blue.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: .blue.opacity(0.25), radius: 6, y: 2)
                Image(systemName: isTyping ? "waveform" : "keyboard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("TypeClipboard")
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Text(shortcut)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                }

                if isTyping && progress.total > 0 {
                    Text("Digitazione \(progress.current)/\(progress.total)… (Esc ferma)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(previewText)
                        .font(.system(size: 11, design: clipboardText.isEmpty ? .default : .monospaced))
                        .foregroundStyle(clipboardText.isEmpty ? .tertiary : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .liquidGlassCard(cornerRadius: 13)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Finestra Impostazioni Liquid Glass

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var typer: Typer
    @StateObject private var ui = SettingsUIState()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var trusted: Bool { ui.trusted }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        ZStack {
            WindowBlurBackground()
                .ignoresSafeArea()

            // Riflessi morbidi di sfondo per valorizzare la rifrazione Liquid Glass
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.16))
                    .frame(width: 240, height: 240)
                    .blur(radius: 65)
                    .offset(x: -130, y: -140)
                Circle()
                    .fill(Color.indigo.opacity(0.16))
                    .frame(width: 240, height: 240)
                    .blur(radius: 70)
                    .offset(x: 140, y: 120)
            }
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                headerHero
                accessibilityCard
                shortcutCard
                timingCard
                footerCard
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 470)
        .fixedSize()
        .onReceive(timer) { _ in ui.trusted = Accessibility.isTrusted(prompt: false) }
    }

    // MARK: Hero Header

    private var headerHero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue, Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .blue.opacity(0.32), radius: 10, y: 4)

                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("TypeClipboard")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("v\(versionString)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .liquidGlassPill(interactive: false)
                }
                Text("Emulazione tastiera fisica per VM, VNC e console remote")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: Card Permesso Accessibilità

    private var accessibilityCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((trusted ? Color.green : Color.orange).opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: trusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(trusted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(trusted ? "Permesso Accessibilità attivo" : "Permesso Accessibilità richiesto")
                    .font(.system(size: 13, weight: .semibold))
                Text(trusted ? "Pronto a inviare keycode fisici alle finestre attive" : "Abilita TypeClipboard in Privacy e sicurezza → Accessibilità")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !trusted {
                Button("Abilita…") {
                    Accessibility.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            } else {
                Text("Attivo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .liquidGlassPill(tint: .green.opacity(0.25), interactive: false)
            }
        }
        .padding(14)
        .liquidGlassCard(
            cornerRadius: 16,
            tint: trusted ? .green.opacity(0.06) : .orange.opacity(0.14)
        )
    }

    // MARK: Card Scorciatoia

    private var shortcutCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.16))
                    .frame(width: 34, height: 34)
                Image(systemName: "command.square.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Scorciatoia globale")
                    .font(.system(size: 13, weight: .semibold))
                Text("Digita gli appunti nella finestra in primo piano")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ShortcutRecorder(settings: settings)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 16)
    }

    // MARK: Card Velocità e Tempi

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                }
                Text("Dinamica di digitazione")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Menu {
                    Button("Rapido (5 ms · avvio 200 ms)") {
                        settings.keyDelayMs = 5
                        settings.initialDelayMs = 200
                    }
                    Button("Bilanciato (10 ms · avvio 300 ms)") {
                        settings.keyDelayMs = 10
                        settings.initialDelayMs = 300
                    }
                    Button("Console remota lenta (35 ms · avvio 500 ms)") {
                        settings.keyDelayMs = 35
                        settings.initialDelayMs = 500
                    }
                } label: {
                    Label("Profili", systemImage: "sparkles")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .controlSize(.small)
            }

            Divider().opacity(0.4)

            // Slider Ritardo tra i tasti
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Ritardo tra i tasti", systemImage: "timer")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Text("\(settings.keyDelayMs) ms")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .liquidGlassPill(interactive: false)
                }
                HStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.keyDelayMs) },
                            set: { settings.keyDelayMs = Int($0.rounded()) }
                        ),
                        in: 0...200,
                        step: 5
                    )
                    Stepper("", value: $settings.keyDelayMs, in: 0...500, step: 5)
                        .labelsHidden()
                        .controlSize(.small)
                }
            }

            // Slider Ritardo iniziale
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Ritardo iniziale", systemImage: "hourglass")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Text("\(settings.initialDelayMs) ms")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .liquidGlassPill(interactive: false)
                }
                HStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.initialDelayMs) },
                            set: { settings.initialDelayMs = Int(($0 / 50).rounded() * 50) }
                        ),
                        in: 0...2000,
                        step: 50
                    )
                    Stepper("", value: $settings.initialDelayMs, in: 0...5000, step: 100)
                        .labelsHidden()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Aumenta il ritardo se la console VNC/VM perde caratteri. Premi **Esc** per fermare.")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 16)
    }

    // MARK: Card Sistema / Footer

    private var footerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.teal)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Avvia automaticamente al login")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Mantieni TypeClipboard attivo nella barra dei menu")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $ui.launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(13)
        .liquidGlassCard(cornerRadius: 16)
    }
}

// MARK: - Registratore Scorciatoia con Keycaps in vetro

struct ShortcutRecorder: View {
    @ObservedObject var settings: Settings
    @StateObject private var recorder = Recorder()

    var body: some View {
        Button {
            recorder.recording ? recorder.stop() : recorder.start(settings)
        } label: {
            if recorder.recording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                    Text("Premi i tasti… (Esc)")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 4) {
                    ForEach(Array(settings.shortcutSymbols.enumerated()), id: \.offset) { _, sym in
                        Text(sym)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(minWidth: 22, minHeight: 22)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.quaternary.opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.white.opacity(0.28), lineWidth: 0.7)
                            )
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
            }
        }
        .buttonStyle(.plain)
        .liquidGlassPill(
            tint: recorder.recording ? .orange.opacity(0.32) : nil,
            interactive: true
        )
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
