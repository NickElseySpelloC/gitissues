//
//  IssueFormWindow.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import AppKit

struct IssueFormWindow: View {
    let windowData: IssueFormWindowData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = WindowCoordinator.shared

    var body: some View {
        IssueFormSheet(
            viewModel: createViewModel(),
            onSuccess: { issue in
                // Notify coordinator of success
                coordinator.notifyIssueFormSuccess(windowId: windowData.id, issue: issue)
            }
        )
        .frame(
            minWidth: 600, maxWidth: 1200,
            minHeight: 700, maxHeight: 1400
        )
        .background(WindowAccessor { window in
            let autosaveName = "GitIssues.IssueFormWindow.\(windowData.mode.rawValue)"

            // Try to restore saved frame
            if let savedFrameString = UserDefaults.standard.string(forKey: autosaveName) {
                let savedFrame = NSRectFromString(savedFrameString)
                window.setFrame(savedFrame, display: false)
            } else {
                // No saved frame - set default
                let defaultWidth: CGFloat = 800
                let defaultHeight: CGFloat = windowData.mode == .create ? 900 : 820
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
    private func createViewModel() -> IssueFormViewModel {
        let apiService = GitHubAPIService(accessToken: windowData.accessToken)

        let mode: IssueFormViewModel.IssueFormMode
        switch windowData.mode {
        case .create:
            mode = .create
        case .edit:
            mode = .edit(issue: Issue(
                id: "",
                number: 0,
                title: "",
                body: nil,
                state: .open,
                createdAt: Date(),
                updatedAt: Date(),
                repository: Repository(id: "", name: "", owner: User(id: "", login: "", avatarUrl: ""), isPrivate: false),
                labels: [],
                assignees: [],
                author: nil
            ))
        }

        // Use the lightweight initializer with actual data
        return IssueFormViewModel(
            apiService: apiService,
            mode: mode,
            issueData: windowData.issueData
        )
    }
}
