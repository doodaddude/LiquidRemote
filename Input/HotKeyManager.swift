import Carbon.HIToolbox

/// System-wide hotkeys via Carbon (works while sandboxed, no Accessibility prompt).
final class HotKeyManager {
    static let shared = HotKeyManager()
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 0
    private var installed = false

    func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        install()
        nextID += 1
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x4C52454D, id: nextID)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs.append(ref)
            handlers[nextID] = action
        }
    }

    private func install() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            DispatchQueue.main.async { HotKeyManager.shared.handlers[id.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
