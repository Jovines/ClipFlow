import AppKit
import SwiftUI

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
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
