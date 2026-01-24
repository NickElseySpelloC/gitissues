//
//  WindowStateService.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import AppKit

/// Service for persisting window sizes and positions
@MainActor
class WindowStateService {
    static let shared = WindowStateService()

    private init() {}

    /// Save window frame for a given identifier
    func saveWindowFrame(_ frame: NSRect, forKey key: String) {
        let frameString = NSStringFromRect(frame)
        UserDefaults.standard.set(frameString, forKey: "WindowFrame_\(key)")
    }

    /// Load saved window frame for a given identifier
    func loadWindowFrame(forKey key: String) -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: "WindowFrame_\(key)") else {
            return nil
        }
        return NSRectFromString(frameString)
    }

    /// Clear saved frame for a given identifier
    func clearWindowFrame(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: "WindowFrame_\(key)")
    }
}
