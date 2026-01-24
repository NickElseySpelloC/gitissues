//
//  IssueDetailViewModel.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine
import AppKit

@MainActor
class IssueDetailViewModel: ObservableObject {
    @Published var issue: Issue
    @Published var comments: [Comment] = []
    @Published var isLoadingComments = false
    @Published var errorMessage: String?
    @Published var isPinned: Bool

    let apiService: GitHubAPIService
    private let pinningService: PinningService
    private weak var listViewModel: IssuesListViewModel?

    init(issue: Issue, apiService: GitHubAPIService, pinningService: PinningService, listViewModel: IssuesListViewModel? = nil) {
        self.issue = issue
        self.apiService = apiService
        self.pinningService = pinningService
        self.listViewModel = listViewModel
        self.isPinned = pinningService.isPinned(issue.id)
    }

    /// Loads the full issue details with comments
    func loadIssueDetails() async {
        isLoadingComments = true
        errorMessage = nil

        do {
            let (updatedIssue, fetchedComments) = try await apiService.fetchIssueDetail(
                owner: issue.repository.owner.login,
                repo: issue.repository.name,
                number: issue.number
            )

            self.issue = updatedIssue
            self.comments = fetchedComments
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingComments = false
    }

    /// Toggles the pin state for this issue
    func togglePin() {
        pinningService.togglePin(issue.id)
        isPinned = pinningService.isPinned(issue.id)

        // Update the list view model's pinned IDs
        listViewModel?.pinnedIssueIDs = pinningService.getPinnedIssues()
    }

    /// Refreshes the main issues list
    func refreshList(afterDelay delay: TimeInterval = 0) async {
        await listViewModel?.loadIssues(afterDelay: delay)
    }

    /// Deletes a comment
    func deleteComment(_ comment: Comment) async {
        do {
            try await apiService.deleteComment(commentId: comment.id)
            // Refresh issue details to reload comments
            await loadIssueDetails()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Shares the issue by copying its GitHub URL to the clipboard
    func shareIssue() {
        let owner = issue.repository.owner.login
        let repo = issue.repository.name
        let number = issue.number
        let url = "https://github.com/\(owner)/\(repo)/issues/\(number)"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
    }

    /// Closes the issue (sets state to closed)
    func closeIssue() async {
        do {
            let updatedIssue = try await apiService.updateIssue(
                issueId: issue.id,
                title: nil,
                body: nil,
                state: .closed
            )
            self.issue = updatedIssue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reopens the issue (sets state to open)
    func reopenIssue() async {
        do {
            let updatedIssue = try await apiService.updateIssue(
                issueId: issue.id,
                title: nil,
                body: nil,
                state: .open
            )
            self.issue = updatedIssue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the issue
    func deleteIssue() async {
        do {
            try await apiService.deleteIssue(issueId: issue.id)
            // Refresh the main issues list with delay to allow GitHub to process
            await refreshList(afterDelay: 1.5)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
