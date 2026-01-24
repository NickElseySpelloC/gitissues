//
//  CommentFormSheet.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import Combine

struct CommentFormSheet: View {
    @StateObject var viewModel: CommentFormViewModel
    @Environment(\.dismiss) private var dismiss
    var onSuccess: ((Comment) -> Void)?
    var onSuccessAndClose: ((Comment) -> Void)?
    var currentIssue: Issue?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.isEditMode ? "Edit Comment" : "Add Comment")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Body editor
                    CommentBodySection(viewModel: viewModel)

                    // Validation errors
                    if !viewModel.validationErrors.isEmpty {
                        ValidationErrorsView(errors: viewModel.validationErrors)
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        ErrorMessageView(message: errorMessage)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                // Show "Save and Close Issue" button if issue is open
                if let issue = currentIssue, issue.state == .open {
                    Button("Save and Close Issue") {
                        Task {
                            do {
                                let comment = try await viewModel.submit()
                                onSuccessAndClose?(comment)
                                dismiss()
                            } catch {
                                // Error is already set in viewModel
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSubmitting)
                }

                Button(viewModel.isEditMode ? "Save Changes" : "Add Comment") {
                    Task {
                        do {
                            let comment = try await viewModel.submit()
                            onSuccess?(comment)
                            dismiss()
                        } catch {
                            // Error is already set in viewModel
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting)
            }
            .padding()
        }
        .frame(width: 700, height: 500) // Set size of comment edit window
    }
}

// MARK: - Comment Body Section
struct CommentBodySection: View {
    @ObservedObject var viewModel: CommentFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text("Comment")
                    .font(.headline)
                Text("(markdown supported)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            MarkdownEditorView(text: $viewModel.body, placeholder: "Write your comment...")
                .frame(height: 330)
                .border(Color.secondary.opacity(0.2), width: 1)
                .cornerRadius(4)
        }
    }
}

// MARK: - Comment Form ViewModel
@MainActor
class CommentFormViewModel: ObservableObject {
    // Form fields
    @Published var body: String = ""

    // UI state
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var validationErrors: [String] = []

    // Dependencies
    private let apiService: GitHubAPIService
    private let mode: CommentFormMode

    // Form mode
    enum CommentFormMode {
        case add(issueId: String)
        case edit(comment: Comment)
    }

    init(apiService: GitHubAPIService, mode: CommentFormMode) {
        self.apiService = apiService
        self.mode = mode

        // Pre-populate fields for edit mode
        switch mode {
        case .add:
            // Start with empty field
            break
        case .edit(let comment):
            self.body = comment.body
        }
    }

    /// Lightweight initializer for window-based forms
    /// Creates the view model from lightweight data structures instead of full domain objects
    init(apiService: GitHubAPIService, mode: CommentFormMode, commentData: CommentFormWindowData.CommentData? = nil) {
        self.apiService = apiService
        self.mode = mode

        switch mode {
        case .add:
            // Start with empty field
            break
        case .edit:
            if let data = commentData {
                self.body = data.body
            }
        }
    }

    /// Returns true if in edit mode
    var isEditMode: Bool {
        switch mode {
        case .add:
            return false
        case .edit:
            return true
        }
    }

    /// Validates the form
    func validate() -> Bool {
        validationErrors.removeAll()

        // Validate body
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.isEmpty {
            validationErrors.append("Comment cannot be empty")
        }

        return validationErrors.isEmpty
    }

    /// Submits the form
    func submit() async throws -> Comment {
        // Clear previous errors
        errorMessage = nil

        // Validate
        guard validate() else {
            throw NSError(domain: "CommentFormViewModel", code: 400, userInfo: [
                NSLocalizedDescriptionKey: validationErrors.joined(separator: "\n")
            ])
        }

        isSubmitting = true

        do {
            let comment: Comment

            switch mode {
            case .add(let issueId):
                comment = try await apiService.addComment(
                    issueId: issueId,
                    body: body
                )

            case .edit(let existingComment):
                comment = try await apiService.updateComment(
                    commentId: existingComment.id,
                    body: body
                )
            }

            isSubmitting = false
            return comment

        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
