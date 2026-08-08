//
//  TransferIssuesSheet.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

/// Whether issues are being copied (fresh copy) or moved (timestamps preserved, original deleted).
enum IssueTransferMode {
    case copy
    case move

    var verb: String { self == .copy ? "Copy" : "Move" }
    var verbing: String { self == .copy ? "Copying" : "Moving" }
    var systemImage: String { self == .copy ? "doc.on.doc" : "arrow.right.square" }
}

/// Sheet that prompts the user to pick a destination repository and confirm before copying or
/// moving the selected issue(s) into it.
struct TransferIssuesSheet: View {
    let mode: IssueTransferMode
    let issues: [Issue]
    @ObservedObject var viewModel: IssuesListViewModel
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case selecting
        case confirming
        case working
        case finished
    }

    @State private var phase: Phase = .selecting
    @State private var repositories: [Repository] = []
    @State private var isLoadingRepos = true
    @State private var searchText = ""
    /// Destination repositories. Copy supports multiple; Move is restricted to one (selecting
    /// another replaces it), since moving deletes the original.
    @State private var selectedRepos: [Repository] = []
    @State private var statusText = ""

    /// Whether the user may pick more than one destination (Copy only).
    private var allowsMultipleDestinations: Bool { mode == .copy }
    @State private var result: TransferResult?

    private var filteredRepositories: [Repository] {
        if searchText.isEmpty { return repositories }
        return repositories.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    private var titleText: String {
        issues.count == 1
            ? "\(mode.verb) Issue to Repository"
            : "\(mode.verb) \(issues.count) Issues to Repository"
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            switch phase {
            case .selecting:
                selectingView
            case .confirming:
                confirmingView
            case .working:
                workingView
            case .finished:
                finishedView
            }
        }
        .frame(width: 440, height: 540)
        .task {
            repositories = await viewModel.fetchSelectableRepositories()
            isLoadingRepos = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            SwiftUI.Label(titleText, systemImage: mode.systemImage)
                .font(.headline)

            Spacer()

            Button {
                dismiss()
                onComplete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(phase == .working)
        }
        .padding()
    }

    // MARK: - Selecting

    private var selectingView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter repositories", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            if allowsMultipleDestinations {
                HStack {
                    Text(selectedRepos.isEmpty
                         ? "Select one or more destination repositories"
                         : "\(selectedRepos.count) repositor\(selectedRepos.count == 1 ? "y" : "ies") selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if isLoadingRepos {
                ProgressView("Loading repositories…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredRepositories.isEmpty {
                Text(searchText.isEmpty ? "No repositories available." : "No repositories match your search.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredRepositories) { repo in
                            RepositoryRow(
                                repository: repo,
                                isSelected: selectedRepos.contains(where: { $0.id == repo.id }),
                                onToggle: { toggleSelection(repo) }
                            )
                            Divider()
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                    onComplete()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Continue") {
                    phase = .confirming
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRepos.isEmpty)
            }
            .padding()
        }
    }

    /// Adds or removes a destination. In multi-select (Copy) mode this toggles membership;
    /// in single-select (Move) mode it replaces the current selection.
    private func toggleSelection(_ repo: Repository) {
        if allowsMultipleDestinations {
            if let index = selectedRepos.firstIndex(where: { $0.id == repo.id }) {
                selectedRepos.remove(at: index)
            } else {
                selectedRepos.append(repo)
            }
        } else {
            selectedRepos = [repo]
        }
    }

    // MARK: - Confirming

    private var confirmingView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: mode.systemImage)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text(confirmationMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)

            Spacer()

            Divider()

            HStack {
                Button("Back") {
                    phase = .selecting
                }

                Spacer()

                Button(mode.verb) {
                    Task { await performTransfer() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    private var confirmationMessage: String {
        guard !selectedRepos.isEmpty else { return "" }
        let subject = issues.count == 1 ? "this issue" : "these \(issues.count) issues"
        let target = selectedRepos.count == 1
            ? selectedRepos[0].fullName
            : "\(selectedRepos.count) repositories"
        return "\(mode.verb) \(subject) to \(target)?"
    }

    private var detailMessage: String {
        switch mode {
        case .copy:
            return "Title, description, labels and comments will be copied. The copy will be created with new timestamps."
        case .move:
            return "Title, description, labels and comments will be transferred with their original timestamps preserved. The original issue\(issues.count == 1 ? "" : "s") will be deleted."
        }
    }

    // MARK: - Working

    private var workingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(statusText)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 16) {
            Spacer()

            if let result = result {
                Image(systemName: result.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(result.failures.isEmpty ? .green : .orange)

                Text(resultSummary(result))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if !result.failures.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(result.failures.enumerated()), id: \.offset) { _, failure in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("#\(failure.issue.number) \(failure.issue.title)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(failure.message)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    .frame(maxHeight: 160)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }

            Spacer()

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    private func resultSummary(_ result: TransferResult) -> String {
        let pastVerb = mode == .copy ? "copied" : "moved"
        let target = selectedRepos.count == 1
            ? (selectedRepos.first?.fullName ?? "the repository")
            : "\(selectedRepos.count) repositories"
        if result.failures.isEmpty {
            return "\(result.succeeded) issue\(result.succeeded == 1 ? "" : "s") \(pastVerb) to \(target)."
        }
        return "\(result.succeeded) of \(result.total) \(pastVerb). \(result.failures.count) failed."
    }

    // MARK: - Actions

    private func performTransfer() async {
        guard !selectedRepos.isEmpty else { return }
        phase = .working
        statusText = "\(mode.verbing) \(issues.count == 1 ? "issue" : "issues")…"

        let progress: (Int, Int) -> Void = { done, total in
            statusText = total > 1 ? "\(mode.verbing) \(done) of \(total)…" : "\(mode.verbing) issue…"
        }

        let outcome: TransferResult
        switch mode {
        case .copy:
            outcome = await viewModel.copyIssues(issues, to: selectedRepos, progress: progress)
        case .move:
            // Move is restricted to a single destination.
            outcome = await viewModel.moveIssues(issues, to: selectedRepos[0], progress: progress)
        }

        result = outcome
        phase = .finished
    }
}
