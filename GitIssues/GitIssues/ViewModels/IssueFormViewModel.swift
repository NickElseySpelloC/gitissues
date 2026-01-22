//
//  IssueFormViewModel.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class IssueFormViewModel: ObservableObject {
    // Form fields
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var initialComment: String = ""
    @Published var selectedState: IssueState = .open
    @Published var selectedRepositoryId: String?

    // UI state
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var validationErrors: [String] = []

    // Dependencies
    private let apiService: GitHubAPIService
    private let mode: IssueFormMode

    // Form mode
    enum IssueFormMode {
        case create(availableRepositories: [Repository])
        case edit(issue: Issue)
    }

    init(apiService: GitHubAPIService, mode: IssueFormMode) {
        self.apiService = apiService
        self.mode = mode

        // Pre-populate fields for edit mode
        switch mode {
        case .create:
            // Start with empty fields
            break
        case .edit(let issue):
            self.title = issue.title
            self.body = issue.body ?? ""
            self.selectedState = issue.state
            self.selectedRepositoryId = issue.repository.id
        }
    }

    /// Returns the available repositories for create mode
    var availableRepositories: [Repository] {
        switch mode {
        case .create(let repositories):
            return repositories
        case .edit:
            return []
        }
    }

    /// Returns true if in create mode
    var isCreateMode: Bool {
        switch mode {
        case .create:
            return true
        case .edit:
            return false
        }
    }

    /// Returns the issue being edited (if in edit mode)
    var editingIssue: Issue? {
        switch mode {
        case .create:
            return nil
        case .edit(let issue):
            return issue
        }
    }

    /// Validates the form
    func validate() -> Bool {
        validationErrors.removeAll()

        // Validate title
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            validationErrors.append("Title is required")
        }

        // Validate repository selection (create mode only)
        if case .create = mode {
            if selectedRepositoryId == nil {
                validationErrors.append("Please select a repository")
            }
        }

        return validationErrors.isEmpty
    }

    /// Submits the form
    func submit() async throws -> Issue {
        // Clear previous errors
        errorMessage = nil

        // Validate
        guard validate() else {
            throw NSError(domain: "IssueFormViewModel", code: 400, userInfo: [
                NSLocalizedDescriptionKey: validationErrors.joined(separator: "\n")
            ])
        }

        isSubmitting = true

        do {
            let issue: Issue

            switch mode {
            case .create:
                guard let repositoryId = selectedRepositoryId else {
                    throw NSError(domain: "IssueFormViewModel", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Repository is required"
                    ])
                }

                issue = try await apiService.createIssue(
                    repositoryId: repositoryId,
                    title: title,
                    body: body.isEmpty ? nil : body
                )

                // Add initial comment if provided
                let trimmedComment = initialComment.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedComment.isEmpty {
                    _ = try await apiService.addComment(
                        issueId: issue.id,
                        body: trimmedComment
                    )
                }

            case .edit(let existingIssue):
                // Only send changed fields
                let titleChanged = title != existingIssue.title
                let bodyChanged = (body.isEmpty ? nil : body) != existingIssue.body
                let stateChanged = selectedState != existingIssue.state

                issue = try await apiService.updateIssue(
                    issueId: existingIssue.id,
                    title: titleChanged ? title : nil,
                    body: bodyChanged ? (body.isEmpty ? nil : body) : nil,
                    state: stateChanged ? selectedState : nil
                )
            }

            isSubmitting = false
            return issue

        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
