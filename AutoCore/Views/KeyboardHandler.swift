import SwiftUI
#if os(macOS)
import AppKit

struct KeyboardHandler: NSViewRepresentable {
    let onTab: () -> Void
    let onShiftTab: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void
    let onArrowUp: (() -> Void)?
    let onArrowDown: (() -> Void)?
    let onArrowLeft: (() -> Void)?
    let onArrowRight: (() -> Void)?
    
    init(
        onTab: @escaping () -> Void,
        onShiftTab: @escaping () -> Void,
        onEnter: @escaping () -> Void,
        onEscape: @escaping () -> Void,
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil,
        onArrowLeft: (() -> Void)? = nil,
        onArrowRight: (() -> Void)? = nil
    ) {
        self.onTab = onTab
        self.onShiftTab = onShiftTab
        self.onEnter = onEnter
        self.onEscape = onEscape
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onArrowLeft = onArrowLeft
        self.onArrowRight = onArrowRight
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardHandlingView()
        view.onTab = onTab
        view.onShiftTab = onShiftTab
        view.onEnter = onEnter
        view.onEscape = onEscape
        view.onArrowUp = onArrowUp
        view.onArrowDown = onArrowDown
        view.onArrowLeft = onArrowLeft
        view.onArrowRight = onArrowRight
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyboardHandlingView {
            view.onTab = onTab
            view.onShiftTab = onShiftTab
            view.onEnter = onEnter
            view.onEscape = onEscape
            view.onArrowUp = onArrowUp
            view.onArrowDown = onArrowDown
            view.onArrowLeft = onArrowLeft
            view.onArrowRight = onArrowRight
        }
    }
}

private class KeyboardHandlingView: NSView {
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onArrowLeft: (() -> Void)?
    var onArrowRight: (() -> Void)?
    
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
        case 126: // Up Arrow
            onArrowUp?()
        case 125: // Down Arrow
            onArrowDown?()
        case 123: // Left Arrow
            onArrowLeft?()
        case 124: // Right Arrow
            onArrowRight?()
        default:
            super.keyDown(with: event)
        }
    }
}
#else
import UIKit

struct KeyboardHandler: View {
    let onTab: () -> Void
    let onShiftTab: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void
    let onArrowUp: (() -> Void)?
    let onArrowDown: (() -> Void)?
    let onArrowLeft: (() -> Void)?
    let onArrowRight: (() -> Void)?
    
    init(
        onTab: @escaping () -> Void,
        onShiftTab: @escaping () -> Void,
        onEnter: @escaping () -> Void,
        onEscape: @escaping () -> Void,
        onArrowUp: (() -> Void)? = nil,
        onArrowDown: (() -> Void)? = nil,
        onArrowLeft: (() -> Void)? = nil,
        onArrowRight: (() -> Void)? = nil
    ) {
        self.onTab = onTab
        self.onShiftTab = onShiftTab
        self.onEnter = onEnter
        self.onEscape = onEscape
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onArrowLeft = onArrowLeft
        self.onArrowRight = onArrowRight
    }
    
    var body: some View { EmptyView() }
}
#endif
