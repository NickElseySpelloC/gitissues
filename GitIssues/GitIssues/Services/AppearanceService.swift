//
//  AppearanceService.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import AppKit
import Combine

enum AppearanceMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light:
            return "Light Mode"
        case .dark:
            return "Dark Mode"
        case .system:
            return "System Default"
        }
    }
}

@MainActor
class AppearanceService: ObservableObject {
    static let shared = AppearanceService()

    @Published var currentMode: AppearanceMode {
        didSet {
            saveMode(currentMode)
            applyMode(currentMode)
        }
    }

    private let userDefaultsKey = "AppearanceMode"

    private init() {
        // Load saved mode or default to system
        if let savedMode = UserDefaults.standard.string(forKey: userDefaultsKey),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            self.currentMode = .system
        }

        // Apply the loaded mode after a brief delay to ensure NSApp is ready
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.applyMode(self.currentMode)
        }
    }

    private func saveMode(_ mode: AppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: userDefaultsKey)
    }

    private func applyMode(_ mode: AppearanceMode) {
        let appearance: NSAppearance?

        switch mode {
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        case .system:
            appearance = nil // nil means follow system
        }

        // Set the appearance on the shared application instance
        NSApplication.shared.appearance = appearance
    }
}
