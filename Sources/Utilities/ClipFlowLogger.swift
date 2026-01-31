import Foundation
import AppKit

enum ClipFlowLogger {
    private static var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "debugMode")
        #endif
    }

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugMode else { return }
        let fileName = (file as NSString).lastPathComponent
        print("[DEBUG] \(fileName):\(line) \(function) - \(message)")
    }

    static func info(_ message: String) {
        print("[INFO] \(message)")
    }

    static func warning(_ message: String) {
        print("[WARNING] \(message)")
    }

    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}
