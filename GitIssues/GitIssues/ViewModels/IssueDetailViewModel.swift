//
//  IssueDetailViewModel.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class IssueDetailViewModel: ObservableObject {
    @Published var issue: Issue
    @Published var comments: [Comment] = []
    @Published var isLoadingComments = false
    @Published var errorMessage: String?
    @Published var isPinned: Bool

    private let apiService: GitHubAPIService
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
}
