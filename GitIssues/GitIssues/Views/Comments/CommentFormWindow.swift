//
//  CommentFormWindow.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import AppKit

struct CommentFormWindow: View {
    let windowData: CommentFormWindowData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = WindowCoordinator.shared

    var body: some View {
        CommentFormSheet(
            viewModel: createViewModel(),
            onSuccess: { comment in
                // Notify coordinator of success
                coordinator.notifyCommentFormSuccess(windowId: windowData.id, comment: comment)
            },
            onSuccessAndClose: { comment in
                // Notify coordinator that issue should be closed
                coordinator.notifyCommentFormSuccessAndClose(windowId: windowData.id, comment: comment)
            },
            currentIssue: createCurrentIssue()
        )
        .frame(
            minWidth: 500, maxWidth: 1000,
            minHeight: 400, maxHeight: 800
        )
        .background(WindowAccessor { window in
            let autosaveName = "GitIssues.CommentFormWindow.\(windowData.mode.rawValue)"

            // Try to restore saved frame
            if let savedFrameString = UserDefaults.standard.string(forKey: autosaveName) {
                let savedFrame = NSRectFromString(savedFrameString)
                window.setFrame(savedFrame, display: false)
            } else {
                // No saved frame - set default
                let defaultWidth: CGFloat = windowData.mode == .edit ? 700 : 525  // Issue 40
                let defaultHeight: CGFloat = 500
                let screenFrame = NSScreen.main?.visibleFrame ?? .zero
                let x = (screenFrame.width - defaultWidth) / 2 + screenFrame.minX
                let y = (screenFrame.height - defaultHeight) / 2 + screenFrame.minY
                window.setFrame(NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight), display: true)
            }

            // Set up observer to save frame when window moves or resizes
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { _ in
                let frameString = NSStringFromRect(window.frame)
                UserDefaults.standard.set(frameString, forKey: autosaveName)
            }

            NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { _ in
                let frameString = NSStringFromRect(window.frame)
                UserDefaults.standard.set(frameString, forKey: autosaveName)
            }
        })
    }

    /// Creates the view model from window data
    private func createViewModel() -> CommentFormViewModel {
        let apiService = GitHubAPIService(accessToken: windowData.accessToken)

        let mode: CommentFormViewModel.CommentFormMode
        switch windowData.mode {
        case .add:
            mode = .add(issueId: windowData.issueId)
        case .edit:
            mode = .edit(comment: Comment(
                id: "",
                body: "",
                author: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }

        // Use the lightweight initializer with actual data
        return CommentFormViewModel(
            apiService: apiService,
            mode: mode,
            commentData: windowData.commentData
        )
    }

    /// Creates a minimal Issue for checking state (for "Save and Close" button)
    private func createCurrentIssue() -> Issue? {
        Issue(
            id: windowData.issueId,
            number: 0,
            title: "",
            body: nil,
            state: IssueState(rawValue: windowData.issueState) ?? .open,
            createdAt: Date(),
            updatedAt: Date(),
            repository: Repository(
                id: "",
                name: "",
                owner: User(id: "", login: "", avatarUrl: ""),
                isPrivate: false
            ),
            labels: [],
            assignees: [],
            author: nil
        )
    }
}
