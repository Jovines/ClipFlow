import AppKit
import SwiftUI

class FloatingWindow: NSWindow {
    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private let screenMargin: CGFloat = 2
    
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
    
    // Allow dragging from the title/header area (top 44 pixels)
    private var dragAreaHeight: CGFloat { 44 }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        
        // Check if click is in the header area (top portion of window)
        if location.y > (self.frame.height - dragAreaHeight) {
            isDragging = true
            dragStartLocation = NSEvent.mouseLocation
            dragStartOrigin = self.frame.origin
        } else {
            isDragging = false
            super.mouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            let currentLocation = NSEvent.mouseLocation
            let deltaX = currentLocation.x - dragStartLocation.x
            let deltaY = currentLocation.y - dragStartLocation.y
            
            var newOrigin = dragStartOrigin
            newOrigin.x += deltaX
            newOrigin.y += deltaY

            if let screen = screen ?? NSScreen.screens.first(where: { $0.frame.contains(currentLocation) }) {
                let visibleFrame = screen.visibleFrame
                let maxX = max(visibleFrame.minX + screenMargin, visibleFrame.maxX - screenMargin - frame.width)
                let maxY = max(visibleFrame.minY + screenMargin, visibleFrame.maxY - screenMargin - frame.height)

                newOrigin.x = min(max(newOrigin.x, visibleFrame.minX + screenMargin), maxX)
                newOrigin.y = min(max(newOrigin.y, visibleFrame.minY + screenMargin), maxY)
            }
            
            self.setFrameOrigin(newOrigin)
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        super.mouseUp(with: event)
    }
}

extension NSTextView {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

class FocusRinglessView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }

    override func drawFocusRingMask() {
    }

    override var focusRingMaskBounds: NSRect {
        return NSRect.zero
    }
}

class FocusRinglessHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = FocusRinglessView()
    }
}
