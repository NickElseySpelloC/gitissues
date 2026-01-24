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
            minWidth: 500, idealWidth: 700, maxWidth: 1000,
            minHeight: 400, idealHeight: 500, maxHeight: 800
        )
        .background(WindowAccessor { window in
            // Use macOS native window frame autosave
            window.setFrameAutosaveName("CommentFormWindow-\(windowData.mode.rawValue)")
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
                fullName: "",
                owner: User(id: "", login: "", avatarUrl: ""),
                isPrivate: false
            ),
            labels: [],
            assignees: [],
            author: nil
        )
    }
}

// Helper view to access NSWindow
struct WindowAccessor: NSViewRepresentable {
    let onWindowConfigured: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.onWindowConfigured(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
