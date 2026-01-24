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
    @Published var availableRepositories: [Repository] = []
    @Published var isLoadingRepositories = false

    // Label management
    @Published var availableLabels: [Label] = []
    @Published var selectedLabelIds: Set<String> = []
    @Published var isLoadingLabels = false

    // UI state
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var validationErrors: [String] = []

    // Dependencies
    private let apiService: GitHubAPIService
    private let mode: IssueFormMode

    // Form mode
    enum IssueFormMode {
        case create
        case edit(issue: Issue)
    }

    init(apiService: GitHubAPIService, mode: IssueFormMode) {
        self.apiService = apiService
        self.mode = mode

        // Pre-populate fields for edit mode
        switch mode {
        case .create:
            // Start with empty fields
            // Load repositories asynchronously
            break
        case .edit(let issue):
            self.title = issue.title
            self.body = issue.body ?? ""
            self.selectedState = issue.state
            self.selectedRepositoryId = issue.repository.id
            // Pre-select existing labels
            self.selectedLabelIds = Set(issue.labels.map { $0.id })
        }
    }

    /// Lightweight initializer for window-based forms
    /// Creates the view model from lightweight data structures instead of full domain objects
    init(apiService: GitHubAPIService, mode: IssueFormMode, issueData: IssueFormWindowData.IssueData? = nil) {
        self.apiService = apiService
        self.mode = mode

        switch mode {
        case .create:
            // Start with empty fields
            break
        case .edit:
            if let data = issueData {
                self.title = data.title
                self.body = data.body ?? ""
                self.selectedState = IssueState(rawValue: data.state) ?? .open
                self.selectedRepositoryId = data.repositoryId
                self.selectedLabelIds = Set(data.labelIds)
            }
        }
    }

    /// Loads available repositories for create mode
    func loadRepositories() async {
        guard case .create = mode else { return }

        isLoadingRepositories = true
        do {
            availableRepositories = try await apiService.fetchAllRepositories()
        } catch {
            errorMessage = "Failed to load repositories: \(error.localizedDescription)"
        }
        isLoadingRepositories = false
    }

    /// Loads labels for the selected repository
    func loadLabels() async {
        // Get the repository info (owner and name)
        guard let repositoryId = selectedRepositoryId else {
            availableLabels = []
            return
        }

        // Find the repository from available repositories or from the editing issue
        let repository: Repository?
        switch mode {
        case .create:
            repository = availableRepositories.first { $0.id == repositoryId }
        case .edit(let issue):
            repository = issue.repository
        }

        guard let repo = repository else {
            availableLabels = []
            return
        }

        isLoadingLabels = true
        do {
            availableLabels = try await apiService.fetchAllRepositoryLabels(
                owner: repo.owner.login,
                repo: repo.name
            )
        } catch {
            errorMessage = "Failed to load labels: \(error.localizedDescription)"
        }
        isLoadingLabels = false
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
                    body: body.isEmpty ? nil : body,
                    labelIds: selectedLabelIds.isEmpty ? nil : Array(selectedLabelIds)
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

                // Handle label changes
                let existingLabelIds = Set(existingIssue.labels.map { $0.id })
                let labelsToAdd = selectedLabelIds.subtracting(existingLabelIds)
                let labelsToRemove = existingLabelIds.subtracting(selectedLabelIds)

                if !labelsToAdd.isEmpty {
                    try await apiService.addLabelsToIssue(
                        issueId: existingIssue.id,
                        labelIds: Array(labelsToAdd)
                    )
                }

                if !labelsToRemove.isEmpty {
                    try await apiService.removeLabelsFromIssue(
                        issueId: existingIssue.id,
                        labelIds: Array(labelsToRemove)
                    )
                }
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
