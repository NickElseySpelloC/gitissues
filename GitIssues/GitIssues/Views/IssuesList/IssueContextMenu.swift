//
//  IssueContextMenu.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

/// Bag of issue-action closures supplied by `ContentView`, so the same context menu can be
/// reused by both the list rows and the Kanban board cards.
struct IssueActions {
    var edit: (Issue) -> Void
    var clone: (Issue) -> Void
    var assign: (Issue) -> Void
    var copyToRepo: ([Issue]) -> Void
    var moveToRepo: ([Issue]) -> Void
    var close: (Issue) -> Void
    var reopen: (Issue) -> Void
    var delete: (Issue) -> Void
    var batchClone: (Set<Issue>) -> Void
    var batchAssign: (Set<Issue>) -> Void
    var batchClose: (Set<Issue>) -> Void
    var batchDelete: (Set<Issue>) -> Void
}

/// The shared right-click menu for an issue. Shows batch operations when the issue is part of a
/// multi-selection, otherwise single-issue operations — matching the original list behaviour.
@ViewBuilder
func issueContextMenu(for issue: Issue, selection: Set<Issue>, actions: IssueActions) -> some View {
    let isBatchTarget = selection.contains(issue) && selection.count > 1
    if isBatchTarget {
        Text("\(selection.count) issues selected")
            .foregroundColor(.secondary)
        Divider()
        Button {
            actions.batchClone(selection)
        } label: {
            SwiftUI.Label("Clone \(selection.count) Issues", systemImage: "doc.on.doc")
        }
        Button {
            actions.batchAssign(selection)
        } label: {
            SwiftUI.Label("Assign \(selection.count) Issues", systemImage: "person.badge.plus")
        }
        Button {
            actions.copyToRepo(Array(selection))
        } label: {
            SwiftUI.Label("Copy \(selection.count) Issues to Repository…", systemImage: "doc.on.doc")
        }
        Button {
            actions.moveToRepo(Array(selection))
        } label: {
            SwiftUI.Label("Move \(selection.count) Issues to Repository…", systemImage: "arrow.right.square")
        }
        let openCount = selection.filter { $0.state == .open }.count
        if openCount > 0 {
            Button {
                actions.batchClose(selection)
            } label: {
                SwiftUI.Label("Close \(openCount) Open Issue\(openCount == 1 ? "" : "s")", systemImage: "checkmark.circle")
            }
        }
        Divider()
        Button(role: .destructive) {
            actions.batchDelete(selection)
        } label: {
            SwiftUI.Label("Delete \(selection.count) Issues", systemImage: "trash")
        }
    } else {
        Button {
            actions.edit(issue)
        } label: {
            SwiftUI.Label("Edit Issue", systemImage: "pencil")
        }
        Button {
            actions.clone(issue)
        } label: {
            SwiftUI.Label("Clone Issue", systemImage: "doc.on.doc")
        }
        Button {
            actions.assign(issue)
        } label: {
            SwiftUI.Label("Assign Issue", systemImage: "person.badge.plus")
        }
        Button {
            actions.copyToRepo([issue])
        } label: {
            SwiftUI.Label("Copy to Repository…", systemImage: "doc.on.doc")
        }
        Button {
            actions.moveToRepo([issue])
        } label: {
            SwiftUI.Label("Move to Repository…", systemImage: "arrow.right.square")
        }
        Divider()
        if issue.state == .open {
            Button {
                actions.close(issue)
            } label: {
                SwiftUI.Label("Close Issue", systemImage: "checkmark.circle")
            }
        } else {
            Button {
                actions.reopen(issue)
            } label: {
                SwiftUI.Label("Reopen Issue", systemImage: "arrow.counterclockwise.circle")
            }
        }
        Divider()
        Button(role: .destructive) {
            actions.delete(issue)
        } label: {
            SwiftUI.Label("Delete Issue", systemImage: "trash")
        }
    }
}
