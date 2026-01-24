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
            minWidth: 600, idealWidth: 800, maxWidth: 1200,
            minHeight: 700, idealHeight: windowData.mode == .create ? 900 : 730, maxHeight: 1400
        )
        .background(WindowAccessor { window in
            // Use macOS native window frame autosave
            window.setFrameAutosaveName("IssueFormWindow-\(windowData.mode.rawValue)")
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
                repository: Repository(id: "", name: "", fullName: "", owner: User(id: "", login: "", avatarUrl: ""), isPrivate: false),
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
