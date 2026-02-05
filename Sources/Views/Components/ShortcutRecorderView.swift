import SwiftUI
import AppKit

struct ShortcutRecorderView: View {
    @Binding var shortcut: HotKeyManager.Shortcut

    @State private var isRecording = false
    @State private var conflictError = false
    @State private var eventMonitor: Any?

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                recordingView
            } else {
                displayView
            }
        }
        .padding(10)
        .background(themeManager.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            startRecording()
        }
    }

    private var recordingView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(themeManager.accent)
                .frame(width: 8, height: 8)

            Text("Press any key...")
                .foregroundStyle(themeManager.textSecondary)

            Spacer()

            Text("ESC to cancel")
                .font(.caption)
                .foregroundStyle(themeManager.textSecondary)
        }
        .onAppear {
            startEventMonitor()
        }
        .onDisappear {
            stopEventMonitor()
        }
    }

    private var displayView: some View {
        HStack(spacing: 8) {
            Text(shortcut.displayString)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()

            Image(systemName: "pencil")
                .foregroundStyle(themeManager.textSecondary)
                .font(.system(size: 12))
        }
        .alert("Shortcut Conflict", isPresented: $conflictError) {
            Button("OK") {}
        } message: {
            Text("This shortcut is already in use or invalid.")
        }
    }
    
    private func startRecording() {
        isRecording = true
        conflictError = false
    }
    
    private func stopRecording() {
        isRecording = false
        stopEventMonitor()
    }
    
    private func startEventMonitor() {
        stopEventMonitor()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC
                self.stopRecording()
                return nil
            }
            
            let modifiers = self.modifiersFromEvent(event)
            let newShortcut = HotKeyManager.Shortcut(keyCode: event.keyCode, modifiers: modifiers)
            
            if self.validateShortcut(newShortcut) {
                self.shortcut = newShortcut
                _ = HotKeyManager.shared.register(newShortcut)
            } else {
                self.conflictError = true
            }
            
            self.isRecording = false
            self.stopEventMonitor()
            return nil
        }
    }
    
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func modifiersFromEvent(_ event: NSEvent) -> NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        return modifiers
    }
    
    private func validateShortcut(_ shortcut: HotKeyManager.Shortcut) -> Bool {
        guard shortcut.isValid else { return false }
        
        // At least one modifier required
        let hasModifier = !shortcut.modifiers.isEmpty
        return hasModifier
    }
}

#Preview {
    ShortcutRecorderView(shortcut: .constant(HotKeyManager.Shortcut(keyCode: kVK_ANSI_V, modifiers: [.command, .shift])))
        .frame(width: 220)
        .padding()
}
