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

    private let apiService: GitHubAPIService
    private let pinningService: PinningService

    init(issue: Issue, apiService: GitHubAPIService, pinningService: PinningService) {
        self.issue = issue
        self.apiService = apiService
        self.pinningService = pinningService
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

    /// Checks if the issue is pinned
    func isPinned() -> Bool {
        pinningService.isPinned(issue.id)
    }

    /// Toggles the pin state for this issue
    func togglePin() {
        pinningService.togglePin(issue.id)
    }
}
