import Foundation
import Carbon
import AppKit

struct Shortcut: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32
    
    static let defaultShortcut = Shortcut(keyCode: 9, modifiers: cmdKey | shiftKey)
    
    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    var displayString: String {
        var parts: [String] = []
        
        if modifiers & cmdKey != 0 { parts.append("⌘") }
        if modifiers & shiftKey != 0 { parts.append("⇧") }
        if modifiers & controlKey != 0 { parts.append("⌃") }
        if modifiers & optionKey != 0 { parts.append("⌥") }
        
        let keyString = keyStringFromKeyCode(keyCode)
        return parts.joined() + keyString
    }
    
    var isValid: Bool {
        keyCode != 0
    }
    
    private func keyStringFromKeyCode(_ code: UInt32) -> String {
        switch code {
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "5"
        case 23: return "6"
        case 24: return "7"
        case 25: return "8"
        case 26: return "9"
        case 27: return "-"
        case 24: return "="
        case 41: return ";"
        case 39: return "'"
        case 42: return "\\"
        case 43: return ","
        case 47: return "."
        case 44: return "/"
        case 49: return "Space"
        case 36: return "Return"
        case 51: return "Delete"
        case 53: return "Escape"
        case 48: return "Tab"
        case 126: return "↑"
        case 125: return "↓"
        case 123: return "←"
        case 124: return "→"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F5"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return ""
        }
    }
    
    static func == (lhs: Shortcut, rhs: Shortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var eventHotKeyRef: EventHotKeyRef?
    
    var onHotKeyPressed: (() -> Void)?
    
    private let userDefaultsKey = "hotkey_shortcut"
    
    private init() {}
    
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        
        guard shortcut.isValid else {
            print("Invalid shortcut")
            return false
        }
        
        if hasConflict(shortcut) {
            return false
        }
        
        let signature = fourCharCode("Clip")
        let id = EventHotKeyID(signature: signature, id: 1)
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            eventHotKeyRef = hotKeyRef
            saveShortcut(shortcut)
            return true
        }
        
        return false
    }
    
    func unregister() {
        if let ref = eventHotKeyRef {
            UnregisterEventHotKey(ref)
            eventHotKeyRef = nil
        }
    }
    
    func loadSavedShortcut() -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
            return Shortcut.defaultShortcut
        }
        return shortcut
    }
    
    func registerSavedShortcut() -> Bool {
        let shortcut = loadSavedShortcut()
        return register(shortcut)
    }
    
    private func saveShortcut(_ shortcut: Shortcut) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func hasConflict(_ shortcut: Shortcut) -> Bool {
        if shortcut.keyCode == 0 {
            return true
        }
        
        if shortcut.keyCode == kVK_Space {
            if shortcut.modifiers == cmdKey || shortcut.modifiers == controlKey {
                return true
            }
        }
        
        return false
    }
    
    private func fourCharCode(_ string: String) -> UInt32 {
        guard string.count == 4 else { return 0 }
        var code: UInt32 = 0
        for char in string {
            if let asciiValue = char.asciiValue {
                code = (code << 8) | UInt32(asciiValue)
            }
        }
        return code
    }
}

let cmdKey: UInt32 = UInt32(1 << 16)
let shiftKey: UInt32 = UInt32(1 << 17)
let controlKey: UInt32 = UInt32(1 << 18)
let optionKey: UInt32 = UInt32(1 << 19)
