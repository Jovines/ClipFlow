import Foundation
import AppKit
import CoreGraphics

final class HotKeyManager: @unchecked Sendable {
    struct Shortcut: Equatable, Codable {
        var keyCode: UInt16
        var modifierFlags: UInt

        static let defaultShortcut = Shortcut(keyCode: kVK_ANSI_V, modifiers: [.command, .shift])

        init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifierFlags = modifiers.rawValue
        }

        init(keyCode: UInt16, modifierFlags: UInt) {
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }

        var modifiers: NSEvent.ModifierFlags {
            get { NSEvent.ModifierFlags(rawValue: modifierFlags) }
            set { modifierFlags = newValue.rawValue }
        }

        var displayString: String {
            var parts: [String] = []

            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.option) { parts.append("⌥") }

            let keyString = keyStringFromKeyCode(keyCode)
            return parts.joined() + keyString
        }

        var isValid: Bool {
            keyCode != 0 && !modifiers.isEmpty
        }

        var carbonModifiers: UInt32 {
            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= cmdKey }
            if modifiers.contains(.shift) { carbonMods |= shiftKey }
            if modifiers.contains(.control) { carbonMods |= controlKey }
            if modifiers.contains(.option) { carbonMods |= optionKey }
            return carbonMods
        }

        private func keyStringFromKeyCode(_ code: UInt16) -> String {
            let keyMap: [UInt16: String] = [
                kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
                kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
                kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
                kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
                kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
                kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
                kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
                kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
                kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
                kVK_ANSI_8: "8", kVK_ANSI_9: "9",
                kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_Semicolon: ";",
                kVK_ANSI_Quote: "'", kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",",
                kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
                kVK_Space: "Space", kVK_Return: "Return", kVK_Delete: "Delete",
                kVK_Escape: "Escape", kVK_Tab: "Tab",
                kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_LeftArrow: "←", kVK_RightArrow: "→",
                kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
                kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
                kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
            ]
            return keyMap[code] ?? ""
        }

        static func == (lhs: Shortcut, rhs: Shortcut) -> Bool {
            lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
        }
    }

    static let shared = HotKeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentUserInfo: AnyObject?

    var onHotKeyPressed: (() -> Void)?

    private let userDefaultsKey = "hotkey_shortcut"
    var currentShortcut: Shortcut?

    private let reservedKeyCodes: Set<UInt16> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
        kVK_F9, kVK_F10, kVK_F11, kVK_F12,
        kVK_Escape, kVK_Command_R, kVK_Command_L,
        kVK_Powerbook_KeybdCommands, kVK_VolumeUp, kVK_VolumeDown, kVK_Mute
    ]

    private init() {}

    func register(_ shortcut: Shortcut) -> Bool {
        guard shortcut.isValid else {
            print("[WARNING] HotKeyManager - Invalid shortcut: must have at least one modifier")
            return false
        }

        let conflict = checkForConflicts(shortcut)
        if let conflict = conflict {
            print("[WARNING] HotKeyManager - Shortcut conflict: \(conflict)")
            return false
        }

        unregister()
        currentShortcut = shortcut
        startMonitoring(shortcut)
        saveShortcut(shortcut)
        return true
    }

    func unregister() {
        stopMonitoring()
        currentShortcut = nil
    }

    func loadSavedShortcut() -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data),
              shortcut.isValid else {
            return Shortcut.defaultShortcut
        }
        return shortcut
    }

    func registerSavedShortcut() -> Bool {
        let shortcut = loadSavedShortcut()
        return register(shortcut)
    }

    private func startMonitoring(_ shortcut: Shortcut) {
        stopMonitoring()

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        class UserInfo {
            let manager: HotKeyManager
            let shortcut: Shortcut

            init(manager: HotKeyManager, shortcut: Shortcut) {
                self.manager = manager
                self.shortcut = shortcut
            }
        }

        let userInfo = UserInfo(manager: self, shortcut: shortcut)
        let userInfoPtr = Unmanaged.passRetained(userInfo).toOpaque()
        currentUserInfo = userInfo as AnyObject

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let userInfo = Unmanaged<UserInfo>.fromOpaque(refcon).takeUnretainedValue()

                if type == .keyDown {
                    let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let eventFlags = UInt(event.flags.rawValue)
                    let shortcut = userInfo.shortcut

                    if UInt16(eventKeyCode) == shortcut.keyCode &&
                       (eventFlags & shortcut.modifierFlags) == shortcut.modifierFlags {
                        let manager = userInfo.manager
                        DispatchQueue.main.async {
                            manager.onHotKeyPressed?()
                        }
                        return nil
                    }
                }

                return Unmanaged.passRetained(event).autorelease()
            },
            userInfo: userInfoPtr
        ) else {
            print("[ERROR] HotKeyManager - Failed to create event tap")
            return
        }

        self.eventTap = eventTap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }

    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        currentUserInfo = nil
    }

    private func checkForConflicts(_ shortcut: Shortcut) -> String? {
        if shortcut.keyCode == 0 {
            return "Invalid key code"
        }

        if reservedKeyCodes.contains(shortcut.keyCode) {
            return "System reserved key"
        }

        if shortcut.keyCode == kVK_Space {
            if shortcut.modifiers.contains(.command) || shortcut.modifiers.contains(.control) {
                return "Conflict with Spotlight/Quick Look"
            }
        }

        return nil
    }

    private func saveShortcut(_ shortcut: Shortcut) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

private let cmdKey: UInt32 = UInt32(1 << 16)
private let shiftKey: UInt32 = UInt32(1 << 17)
private let controlKey: UInt32 = UInt32(1 << 18)
private let optionKey: UInt32 = UInt32(1 << 19)

let kVK_ANSI_A: UInt16 = 0x00
let kVK_ANSI_B: UInt16 = 0x0B
let kVK_ANSI_C: UInt16 = 0x08
let kVK_ANSI_D: UInt16 = 0x02
let kVK_ANSI_E: UInt16 = 0x0E
let kVK_ANSI_F: UInt16 = 0x03
let kVK_ANSI_G: UInt16 = 0x05
let kVK_ANSI_H: UInt16 = 0x04
let kVK_ANSI_I: UInt16 = 0x22
let kVK_ANSI_J: UInt16 = 0x26
let kVK_ANSI_K: UInt16 = 0x28
let kVK_ANSI_L: UInt16 = 0x25
let kVK_ANSI_M: UInt16 = 0x2E
let kVK_ANSI_N: UInt16 = 0x2D
let kVK_ANSI_O: UInt16 = 0x1F
let kVK_ANSI_P: UInt16 = 0x23
let kVK_ANSI_Q: UInt16 = 0x0C
let kVK_ANSI_R: UInt16 = 0x0F
let kVK_ANSI_S: UInt16 = 0x01
let kVK_ANSI_T: UInt16 = 0x11
let kVK_ANSI_U: UInt16 = 0x20
let kVK_ANSI_V: UInt16 = 0x09
let kVK_ANSI_W: UInt16 = 0x0D
let kVK_ANSI_X: UInt16 = 0x07
let kVK_ANSI_Y: UInt16 = 0x10
let kVK_ANSI_Z: UInt16 = 0x06
let kVK_ANSI_0: UInt16 = 0x1D
let kVK_ANSI_1: UInt16 = 0x12
let kVK_ANSI_2: UInt16 = 0x13
let kVK_ANSI_3: UInt16 = 0x14
let kVK_ANSI_4: UInt16 = 0x15
let kVK_ANSI_5: UInt16 = 0x16
let kVK_ANSI_6: UInt16 = 0x17
let kVK_ANSI_7: UInt16 = 0x1A
let kVK_ANSI_8: UInt16 = 0x1C
let kVK_ANSI_9: UInt16 = 0x19
let kVK_ANSI_Minus: UInt16 = 0x1B
let kVK_ANSI_Equal: UInt16 = 0x18
let kVK_ANSI_Semicolon: UInt16 = 0x29
let kVK_ANSI_Quote: UInt16 = 0x27
let kVK_ANSI_Backslash: UInt16 = 0x2A
let kVK_ANSI_Comma: UInt16 = 0x2B
let kVK_ANSI_Period: UInt16 = 0x2F
let kVK_ANSI_Slash: UInt16 = 0x2C
let kVK_Space: UInt16 = 0x31
let kVK_Return: UInt16 = 0x24
let kVK_Delete: UInt16 = 0x33
let kVK_Escape: UInt16 = 0x35
let kVK_Tab: UInt16 = 0x30
let kVK_UpArrow: UInt16 = 0x7E
let kVK_DownArrow: UInt16 = 0x7D
let kVK_LeftArrow: UInt16 = 0x7B
let kVK_RightArrow: UInt16 = 0x7C
let kVK_F1: UInt16 = 0x7A
let kVK_F2: UInt16 = 0x78
let kVK_F3: UInt16 = 0x63
let kVK_F4: UInt16 = 0x76
let kVK_F5: UInt16 = 0x60
let kVK_F6: UInt16 = 0x61
let kVK_F7: UInt16 = 0x62
let kVK_F8: UInt16 = 0x64
let kVK_F9: UInt16 = 0x65
let kVK_F10: UInt16 = 0x6D
let kVK_F11: UInt16 = 0x67
let kVK_F12: UInt16 = 0x6F
let kVK_Command_R: UInt16 = 0x36
let kVK_Command_L: UInt16 = 0x37
let kVK_Powerbook_KeybdCommands: UInt16 = 0x60
let kVK_VolumeUp: UInt16 = 0x48
let kVK_VolumeDown: UInt16 = 0x49
let kVK_Mute: UInt16 = 0x4A
