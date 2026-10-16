import AppKit
import CoreGraphics

/// Digita un testo inviando eventi tastiera (CGEvent).
final class Typer {
    private let queue = DispatchQueue(label: "TypeClipboard.typer")
    private let lock = NSLock()
    private var _cancelled = false
    private var cancelled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _cancelled }
        set { lock.lock(); _cancelled = newValue; lock.unlock() }
    }

    private static let kShift: CGKeyCode = 56
    private static let kOption: CGKeyCode = 58
    private static let kReturn: CGKeyCode = 36
    private static let kTab: CGKeyCode = 48

    func cancel() { cancelled = true }

    /// Da chiamare sul main thread (il mapper legge il layout attivo).
    func type(_ text: String, keyDelayMs: Int, initialDelayMs: Int) {
        let mapper = KeyboardLayoutMapper()
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        cancelled = false

        queue.async { [self] in
            waitForModifiersRelease()
            usleep(useconds_t(max(0, initialDelayMs)) * 1000)
            let source = CGEventSource(stateID: .hidSystemState)
            let delay = useconds_t(max(0, keyDelayMs)) * 1000

            for ch in normalized {
                if cancelled { break }
                switch ch {
                case "\n": tap(KeyStroke(keyCode: Self.kReturn, shift: false, option: false), source)
                case "\t": tap(KeyStroke(keyCode: Self.kTab, shift: false, option: false), source)
                default:
                    if let stroke = mapper.map[ch] {
                        tap(stroke, source)
                    } else {
                        typeUnicode(String(ch), source)
                    }
                }
                if delay > 0 { usleep(delay) }
            }
        }
    }

    /// Aspetta che l'utente rilasci i modificatori della scorciatoia (es. ⌃⌥).
    private func waitForModifiersRelease() {
        let mask: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        for _ in 0..<150 { // max ~3 s
            if CGEventSource.flagsState(.combinedSessionState).intersection(mask).isEmpty { return }
            usleep(20_000)
        }
    }

    private func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags, _ source: CGEventSource?) {
        guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return }
        e.flags = flags
        e.post(tap: .cghidEventTap)
    }

    /// Preme davvero Shift/Option (molte console remote guardano lo stato dei tasti, non solo i flag).
    private func tap(_ s: KeyStroke, _ source: CGEventSource?) {
        var flags: CGEventFlags = []
        if s.shift { flags.insert(.maskShift); post(Self.kShift, down: true, flags: flags, source) }
        if s.option { flags.insert(.maskAlternate); post(Self.kOption, down: true, flags: flags, source) }
        if s.shift || s.option { usleep(2_000) }

        post(s.keyCode, down: true, flags: flags, source)
        usleep(1_000)
        post(s.keyCode, down: false, flags: flags, source)

        if s.option { flags.remove(.maskAlternate); post(Self.kOption, down: false, flags: flags, source) }
        if s.shift { flags.remove(.maskShift); post(Self.kShift, down: false, flags: flags, source) }
    }

    /// Ripiego per caratteri non presenti nel layout (emoji ecc.).
    private func typeUnicode(_ s: String, _ source: CGEventSource?) {
        let utf16 = Array(s.utf16)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            e.flags = []
            e.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            e.post(tap: .cghidEventTap)
        }
    }
}
