import AppKit
import Carbon

@MainActor final class ShortcutController {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var installedKey: UInt32?
    private var installedModifiers: UInt32?
    var action: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<ShortcutController>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { controller.action?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(key: UInt32, modifiers: UInt32) -> Bool {
        if installedKey == key && installedModifiers == modifiers { return true }
        let old = hotKey
        if let old { UnregisterEventHotKey(old) }
        hotKey = nil
        let identifier = EventHotKeyID(signature: OSType(0x4449534C), id: 1)
        let status = RegisterEventHotKey(key, modifiers, identifier, GetApplicationEventTarget(), 0, &hotKey)
        installedKey = status == noErr ? key : nil
        installedModifiers = status == noErr ? modifiers : nil
        return status == noErr
    }
}
