//
//  WindowAccessor.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import AppKit

/// Helper view to access NSWindow for configuration
struct WindowAccessor: NSViewRepresentable {
    let onWindowConfigured: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Use a coordinator to track if we've already configured the window
        DispatchQueue.main.async {
            if let window = view.window, !context.coordinator.isConfigured {
                context.coordinator.isConfigured = true
                self.onWindowConfigured(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Check again in update in case window wasn't available during makeNSView
        if let window = nsView.window, !context.coordinator.isConfigured {
            context.coordinator.isConfigured = true
            onWindowConfigured(window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var isConfigured = false
    }
}
