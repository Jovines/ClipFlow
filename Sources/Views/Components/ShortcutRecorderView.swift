import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: Shortcut
    
    @State private var isRecording = false
    @State private var conflictError = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                recordingView
            } else {
                displayView
            }
        }
        .padding(10)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            startRecording()
        }
    }
    
    private var recordingView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Text("Press any key...")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("ESC to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Spacer()
            
            Image(systemName: "pencil")
                .foregroundStyle(.secondary)
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
            let newShortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            
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
    
    private func modifiersFromEvent(_ event: NSEvent) -> UInt32 {
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { modifiers |= cmdKey }
        if event.modifierFlags.contains(.shift) { modifiers |= shiftKey }
        if event.modifierFlags.contains(.control) { modifiers |= controlKey }
        if event.modifierFlags.contains(.option) { modifiers |= optionKey }
        return modifiers
    }
    
    private func validateShortcut(_ shortcut: Shortcut) -> Bool {
        guard shortcut.isValid else { return false }
        
        // At least one modifier required
        let hasModifier = shortcut.modifiers != 0
        return hasModifier
    }
}

#Preview {
    ShortcutRecorderView(shortcut: .constant(Shortcut(keyCode: 9, modifiers: cmdKey | shiftKey)))
        .frame(width: 220)
        .padding()
}
