import AppKit
import Carbon.HIToolbox

struct KeyStroke {
    let keyCode: CGKeyCode
    let shift: Bool
    let option: Bool
}

/// Costruisce una mappa carattere -> tasto fisico (+ Shift/Option) dal layout di tastiera attivo
/// (es. Italiano), così le console remote ricevono keycode reali e non solo stringhe Unicode.
/// Va creato sul main thread (API TIS).
final class KeyboardLayoutMapper {
    private(set) var map: [Character: KeyStroke] = [:]

    init() {
        guard let data = Self.currentLayoutData() else { return }
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            // modifierKeyState per UCKeyTranslate = (modificatori Carbon >> 8) & 0xFF
            let combos: [(state: UInt32, shift: Bool, option: Bool)] = [
                (0, false, false), (2, true, false), (8, false, true), (10, true, true),
            ]
            for combo in combos {
                for code in 0..<128 where !(65...92).contains(code) { // salta il tastierino numerico
                    let (s, isDead) = Self.translate(layout, keyCode: UInt16(code), modifierState: combo.state)
                    guard !isDead, s.count == 1, let ch = s.first, map[ch] == nil,
                          let scalar = ch.unicodeScalars.first, scalar.value >= 0x20, scalar.value != 0x7F
                    else { continue }
                    map[ch] = KeyStroke(keyCode: CGKeyCode(code), shift: combo.shift, option: combo.option)
                }
            }
        }
    }

    static func currentLayoutData() -> Data? {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        return Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
    }

    static func translate(_ layout: UnsafePointer<UCKeyboardLayout>, keyCode: UInt16,
                          modifierState: UInt32) -> (String, Bool) {
        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), modifierState,
                                    UInt32(LMGetKbdType()), 0, &deadKeyState, chars.count, &length, &chars)
        guard status == noErr else { return ("", false) }
        return (String(utf16CodeUnits: chars, count: length), deadKeyState != 0)
    }

    /// Nome leggibile di un tasto (per mostrare la scorciatoia).
    static func keyName(for keyCode: UInt32) -> String {
        let special: [UInt32: String] = [
            36: "↩", 48: "⇥", 49: "Spazio", 51: "⌫", 53: "Esc", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        if let s = special[keyCode] { return s }
        guard let data = currentLayoutData() else { return "#\(keyCode)" }
        let s = data.withUnsafeBytes { raw -> String in
            let layout = raw.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
            return translate(layout, keyCode: UInt16(keyCode), modifierState: 0).0
        }
        return s.isEmpty ? "#\(keyCode)" : s.uppercased()
    }
}
