//
//  WindowCoordinator.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine
import SwiftUI

/// Singleton coordinator for managing window communication and events
@MainActor
class WindowCoordinator: ObservableObject {
    static let shared = WindowCoordinator()

    // MARK: - Publishers

    /// Emitted when an issue form successfully creates or updates an issue
    /// Parameters: (windowId, issue)
    let issueFormSuccess = PassthroughSubject<(UUID, Issue), Never>()

    /// Emitted when a comment form successfully creates or updates a comment
    /// Parameters: (windowId, comment)
    let commentFormSuccess = PassthroughSubject<(UUID, Comment), Never>()

    /// Emitted when a comment is saved and the issue should be closed
    /// Parameters: (windowId, comment)
    let commentFormSuccessAndClose = PassthroughSubject<(UUID, Comment), Never>()

    // MARK: - Initialization

    private init() {}

    // MARK: - Event Emitters

    /// Notify subscribers that an issue form completed successfully
    func notifyIssueFormSuccess(windowId: UUID, issue: Issue) {
        issueFormSuccess.send((windowId, issue))
    }

    /// Notify subscribers that a comment form completed successfully
    func notifyCommentFormSuccess(windowId: UUID, comment: Comment) {
        commentFormSuccess.send((windowId, comment))
    }

    /// Notify subscribers that a comment was saved and issue should be closed
    func notifyCommentFormSuccessAndClose(windowId: UUID, comment: Comment) {
        commentFormSuccessAndClose.send((windowId, comment))
    }
}
