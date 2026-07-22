//
//  KanbanState.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

/// A single Kanban workflow state (i.e. a board column). Persisted in user settings.
struct KanbanState: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    /// When an issue is in this state, is it Open or Closed on GitHub?
    var isClosed: Bool

    init(id: UUID = UUID(), name: String, isClosed: Bool) {
        self.id = id
        self.name = name
        self.isClosed = isClosed
    }
}

/// Pure, non-isolated helpers for the Kanban label convention.
///
/// Kept separate from `KanbanSettingsService` (which is `@MainActor`) so these can be used
/// freely from SwiftUI view bodies, models, and background tasks without actor hops.
enum Kanban {
    /// Prefix shared by all Kanban state labels, e.g. `kanban-In Progress`.
    static let labelPrefix = "kanban-"

    /// The GitHub label name that represents a given state.
    static func labelName(for state: KanbanState) -> String {
        labelPrefix + state.name
    }

    /// True if a label name uses the Kanban prefix — ours or another user's.
    /// Used for *hiding* labels; behaviour (placement/move) is limited to configured states.
    static func isKanbanLabel(_ name: String) -> Bool {
        name.lowercased().hasPrefix(labelPrefix)
    }

    /// Labels with every Kanban-prefixed label removed (for display and editing).
    static func visibleLabels(_ labels: [Label]) -> [Label] {
        labels.filter { !isKanbanLabel($0.name) }
    }

    /// Palette used when auto-creating Kanban labels, cycled by column index.
    static let palette = ["1f6feb", "8250df", "d29922", "1a7f37", "cf222e", "6e7781"]

    /// A stable color (6-char hex, no `#`) for the Nth column.
    static func color(forIndex index: Int) -> String {
        let count = palette.count
        return palette[((index % count) + count) % count]
    }
}
