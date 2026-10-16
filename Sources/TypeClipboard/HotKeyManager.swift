import AppKit
import Carbon.HIToolbox

/// Scorciatoia globale tramite Carbon `RegisterEventHotKey` (non richiede permessi).
final class HotKeyManager {
    var handler: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.handler?() }
            return noErr
        }, 1, &spec, userData, &eventHandler)
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x5459_434C), id: 1) // 'TYCL'
        let status = RegisterEventHotKey(keyCode, Self.carbonFlags(modifiers), id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    static func carbonFlags(_ m: NSEvent.ModifierFlags) -> UInt32 {
        var f: UInt32 = 0
        if m.contains(.command) { f |= UInt32(cmdKey) }
        if m.contains(.control) { f |= UInt32(controlKey) }
        if m.contains(.option) { f |= UInt32(optionKey) }
        if m.contains(.shift) { f |= UInt32(shiftKey) }
        return f
    }
}
