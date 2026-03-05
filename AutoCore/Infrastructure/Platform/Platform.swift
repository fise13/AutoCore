//
//  Platform.swift
//  AutoCore
//
//  Cross-platform helpers for macOS and iOS.
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
typealias PlatformFont = NSFont
#else
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformFont = UIFont
#endif

enum Platform {
    static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    /// Control/surface background color
    static var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    /// Window/screen background
    static var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    /// Secondary label (caption) color
    static var secondaryLabelColor: Color {
        #if os(macOS)
        return Color(NSColor.secondaryLabelColor)
        #else
        return Color(UIColor.secondaryLabel)
        #endif
    }
    
    /// Separator color
    static var separatorColor: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(UIColor.separator)
        #endif
    }
    
    /// Text / cell background
    static var textBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    /// Accent (tint)
    static var controlAccentColor: Color {
        #if os(macOS)
        return Color(NSColor.controlAccentColor)
        #else
        return Color(UIColor.tintColor)
        #endif
    }
    
    /// Selected content background
    static var selectedContentBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.selectedContentBackgroundColor)
        #else
        return Color(UIColor.secondarySystemFill)
        #endif
    }
    
    /// Copy string to system pasteboard
    static func copyToPasteboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}
