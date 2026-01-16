import SwiftUI
import AppKit

struct KeyboardHandler: NSViewRepresentable {
    let onTab: () -> Void
    let onShiftTab: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardHandlingView()
        view.onTab = onTab
        view.onShiftTab = onShiftTab
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyboardHandlingView {
            view.onTab = onTab
            view.onShiftTab = onShiftTab
            view.onEnter = onEnter
            view.onEscape = onEscape
        }
    }
}

private class KeyboardHandlingView: NSView {
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags
        
        switch event.keyCode {
        case 48: // Tab
            if flags.contains(.shift) {
                onShiftTab?()
            } else {
                onTab?()
            }
        case 36: // Enter
            onEnter?()
        case 53: // Escape
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}
