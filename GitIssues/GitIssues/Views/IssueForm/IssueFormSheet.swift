//
//  IssueFormSheet.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct IssueFormSheet: View {
    @StateObject var viewModel: IssueFormViewModel
    @Environment(\.dismiss) private var dismiss
    var onSuccess: ((Issue) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.isCreateMode ? "New Issue" : "Edit Issue")
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
                    // Repository picker (create mode only)
                    if viewModel.isCreateMode {
                        RepositoryPickerSection(viewModel: viewModel)
                    }

                    // Title field
                    TitleSection(viewModel: viewModel)

                    // Body editor
                    BodySection(viewModel: viewModel)

                    // Initial comment (create mode only)
                    if viewModel.isCreateMode {
                        InitialCommentSection(viewModel: viewModel)
                    }

                    // State picker (edit mode only)
                    if !viewModel.isCreateMode {
                        StatePickerSection(viewModel: viewModel)
                    }

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

                Button(viewModel.isCreateMode ? "Create Issue" : "Save Changes") {
                    Task {
                        do {
                            let issue = try await viewModel.submit()
                            onSuccess?(issue)
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
        .frame(width: 600, height: 700)
    }
}

// MARK: - Repository Picker Section
struct RepositoryPickerSection: View {
    @ObservedObject var viewModel: IssueFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text("Repository")
                    .font(.headline)
                Text("*")
                    .foregroundColor(.red)
            }

            Picker("", selection: $viewModel.selectedRepositoryId) {
                Text("Select a repository...")
                    .tag(nil as String?)

                ForEach(viewModel.availableRepositories) { repo in
                    Text(repo.fullName)
                        .tag(repo.id as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Title Section
struct TitleSection: View {
    @ObservedObject var viewModel: IssueFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(.secondary)
                Text("Title")
                    .font(.headline)
                Text("*")
                    .foregroundColor(.red)
            }

            TextField("Enter issue title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Body Section
struct BodySection: View {
    @ObservedObject var viewModel: IssueFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text("Description")
                    .font(.headline)
                Text("(optional, markdown supported)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $viewModel.body)
                .font(.body)
                .frame(height: 200)
                .border(Color.secondary.opacity(0.2), width: 1)
                .cornerRadius(4)
        }
    }
}

// MARK: - Initial Comment Section
struct InitialCommentSection: View {
    @ObservedObject var viewModel: IssueFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bubble.left")
                    .foregroundColor(.secondary)
                Text("Initial Comment")
                    .font(.headline)
                Text("(optional, markdown supported)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $viewModel.initialComment)
                .font(.body)
                .frame(height: 150)
                .border(Color.secondary.opacity(0.2), width: 1)
                .cornerRadius(4)
        }
    }
}

// MARK: - State Picker Section
struct StatePickerSection: View {
    @ObservedObject var viewModel: IssueFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                Text("State")
                    .font(.headline)
            }

            HStack(spacing: 16) {
                // Open state button
                Button {
                    viewModel.selectedState = .open
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.selectedState == .open ? "circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedState == .open ? .accentColor : .secondary)
                        Text("Open")
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.selectedState == .open
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.selectedState == .open
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)

                // Closed state button
                Button {
                    viewModel.selectedState = .closed
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.selectedState == .closed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedState == .closed ? .accentColor : .secondary)
                        Text("Closed")
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.selectedState == .closed
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.selectedState == .closed
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Validation Errors View
struct ValidationErrorsView: View {
    let errors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(errors, id: \.self) { error in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Error Message View
struct ErrorMessageView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle")
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}
