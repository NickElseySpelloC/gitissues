//
//  PinningService.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

class PinningService {
    private let defaults = UserDefaults.standard
    private let pinnedIssuesKey = "pinnedIssues"

    /// Returns the set of pinned issue IDs
    func getPinnedIssues() -> Set<String> {
        if let pinnedArray = defaults.array(forKey: pinnedIssuesKey) as? [String] {
            return Set(pinnedArray)
        }
        return []
    }

    /// Checks if an issue is pinned
    func isPinned(_ issueID: String) -> Bool {
        return getPinnedIssues().contains(issueID)
    }

    /// Pins an issue
    func pin(_ issueID: String) {
        var pinned = getPinnedIssues()
        pinned.insert(issueID)
        save(pinned)
    }

    /// Unpins an issue
    func unpin(_ issueID: String) {
        var pinned = getPinnedIssues()
        pinned.remove(issueID)
        save(pinned)
    }

    /// Toggles the pinned state of an issue
    func togglePin(_ issueID: String) {
        if isPinned(issueID) {
            unpin(issueID)
        } else {
            pin(issueID)
        }
    }

    /// Pins multiple issues at once
    func pinMultiple(_ issueIDs: [String]) {
        var pinned = getPinnedIssues()
        pinned.formUnion(issueIDs)
        save(pinned)
    }

    /// Unpins multiple issues at once
    func unpinMultiple(_ issueIDs: [String]) {
        var pinned = getPinnedIssues()
        pinned.subtract(issueIDs)
        save(pinned)
    }

    /// Clears all pinned issues
    func clearAll() {
        save(Set<String>())
    }

    private func save(_ pinned: Set<String>) {
        defaults.set(Array(pinned), forKey: pinnedIssuesKey)
    }
}
