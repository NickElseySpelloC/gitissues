//
//  IssueDetailView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import Combine

struct IssueDetailView: View {
    @State private var activeCommentWindowId: UUID?
    @State private var activeIssueFormWindowId: UUID?

    @ObservedObject var viewModel: IssueDetailViewModel
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var authManager: OAuth2Manager
    @StateObject private var coordinator = WindowCoordinator.shared
    @State private var showDeleteConfirmation = false
    @State private var commentToDelete: Comment?
    @State private var showDeleteIssueConfirmation = false
    @State private var isShareAnimating = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                IssueHeaderView(
                    issue: viewModel.issue,
                    isPinned: viewModel.isPinned,
                    isShareAnimating: isShareAnimating,
                    onPinToggle: {
                        viewModel.togglePin()
                    },
                    onEditTapped: {
                        if let accessToken = authManager.getAccessToken() {
                            let issueData = IssueFormWindowData.IssueData(
                                issueId: viewModel.issue.id,
                                title: viewModel.issue.title,
                                body: viewModel.issue.body,
                                state: viewModel.issue.state.rawValue,
                                repositoryId: viewModel.issue.repository.id,
                                repositoryOwner: viewModel.issue.repository.owner.login,
                                repositoryName: viewModel.issue.repository.name,
                                labelIds: viewModel.issue.labels.map { $0.id }
                            )
                            let windowData = IssueFormWindowData(
                                mode: .edit,
                                accessToken: accessToken,
                                issueData: issueData
                            )
                            openWindow(id: WindowIdentifier.issueForm.rawValue, value: windowData)
                            activeIssueFormWindowId = windowData.id
                        }
                    },
                    onDeleteTapped: {
                        showDeleteIssueConfirmation = true
                    },
                    onShareTapped: {
                        viewModel.shareIssue()
                        // Animate the share button
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShareAnimating = true
                        }
                        // Reset after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isShareAnimating = false
                            }
                        }
                    }
                )

                Divider()

                // Metadata
                IssueMetadataView(issue: viewModel.issue)

                // Labels
                if !viewModel.issue.labels.isEmpty {
                    LabelsSection(labels: viewModel.issue.labels)
                }

                // Assignees
                if !viewModel.issue.assignees.isEmpty {
                    AssigneesSection(assignees: viewModel.issue.assignees)
                }

                Divider()

                // Issue body
                if let body = viewModel.issue.body, !body.isEmpty {
                    IssueBodyView(bodyText: body, author: viewModel.issue.author, apiService: viewModel.apiService)
                } else {
                    Text("No description provided")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                }

                // Comments section
                CommentsSection(
                    comments: viewModel.comments,
                    isLoading: viewModel.isLoadingComments,
                    apiService: viewModel.apiService,
                    onAddComment: {
                        if let accessToken = authManager.getAccessToken() {
                            let windowData = CommentFormWindowData(
                                mode: .add,
                                accessToken: accessToken,
                                issueId: viewModel.issue.id,
                                issueState: viewModel.issue.state.rawValue
                            )
                            openWindow(id: WindowIdentifier.commentForm.rawValue, value: windowData)
                            activeCommentWindowId = windowData.id
                        }
                    },
                    onEditComment: { comment in
                        if let accessToken = authManager.getAccessToken() {
                            let commentData = CommentFormWindowData.CommentData(
                                commentId: comment.id,
                                body: comment.body
                            )
                            let windowData = CommentFormWindowData(
                                mode: .edit,
                                accessToken: accessToken,
                                issueId: viewModel.issue.id,
                                issueState: viewModel.issue.state.rawValue,
                                commentData: commentData
                            )
                            openWindow(id: WindowIdentifier.commentForm.rawValue, value: windowData)
                            activeCommentWindowId = windowData.id
                        }
                    },
                    onDeleteComment: { comment in
                        commentToDelete = comment
                        showDeleteConfirmation = true
                    }
                )

                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadIssueDetails()

            // Subscribe to coordinator events
            coordinator.issueFormSuccess
                .sink { (windowId, issue) in
                    Task {
                        // Update local issue and refresh details
                        viewModel.issue = issue
                        await viewModel.loadIssueDetails()
                        // Also refresh the main issues list with delay
                        await viewModel.refreshList(afterDelay: 1.5)
                    }
                }
                .store(in: &cancellables)

            coordinator.commentFormSuccess
            .sink { (windowId, comment) in
                guard windowId == activeCommentWindowId else { return }
                    Task {
                        await viewModel.loadIssueDetails()
                    }
                }
                .store(in: &cancellables)

            coordinator.commentFormSuccessAndClose
            .sink { (windowId, comment) in
                guard windowId == activeCommentWindowId else { return }
                    Task {
                        await viewModel.closeIssue()
                        await viewModel.loadIssueDetails()
                        await viewModel.refreshList(afterDelay: 1.5)
                    }
                }
                .store(in: &cancellables)
        }
        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                commentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let comment = commentToDelete {
                    Task {
                        await viewModel.deleteComment(comment)
                        commentToDelete = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
        .alert("Delete Issue", isPresented: $showDeleteIssueConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteIssue()
                }
            }
        } message: {
            Text("Are you sure you want to delete this issue? This action cannot be undone.")
        }
    }
}

// MARK: - Issue Header
struct IssueHeaderView: View {
    let issue: Issue
    let isPinned: Bool
    let isShareAnimating: Bool
    let onPinToggle: () -> Void
    let onEditTapped: () -> Void
    let onDeleteTapped: () -> Void
    let onShareTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // State icon
                Image(systemName: issue.state == .open ? "circle" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(issue.state == .open ? .green : .purple)

                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(issue.title)
                        .font(.title)
                        .fontWeight(.bold)

                    // Issue number and state
                    HStack {
                        Text("#\(issue.number)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(issue.state == .open ? "Open" : "Closed")
                            .font(.headline)
                            .foregroundColor(issue.state == .open ? .green : .purple)
                    }
                }

                Spacer()

                // Edit button
                Button(action: onEditTapped) {
                    Text("Edit")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .help("Edit issue")

                // Pin button
                Button(action: onPinToggle) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.title2)
                        .foregroundColor(isPinned ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin issue" : "Pin issue")

                // Delete button
                Button(action: onDeleteTapped) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete issue")

                // Share button
                Button(action: onShareTapped) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(isShareAnimating ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy GitHub URL to clipboard")
            }
        }
    }
}

// MARK: - Metadata
struct IssueMetadataView: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.secondary)
                if let author = issue.author {
                    Text(author.login)
                        .font(.subheadline)
                } else {
                    Text("Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("opened this issue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text("Created \(issue.createdAt, style: .relative)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Updated \(issue.updatedAt, style: .relative)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text(issue.repository.fullName)
                    .font(.subheadline)
            }
        }
        .font(.caption)
    }
}

// MARK: - Labels Section
struct LabelsSection: View {
    let labels: [Label]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.secondary)
                Text("Labels")
                    .font(.headline)
            }

            FlowLayout(spacing: 6) {
                ForEach(labels) { label in
                    LabelBadge(label: label)
                }
            }
        }
    }
}

// MARK: - Assignees Section
struct AssigneesSection: View {
    let assignees: [User]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.secondary)
                Text("Assignees")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(assignees) { assignee in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(assignee.login)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Issue Body
struct IssueBodyView: View {
    let bodyText: String
    let author: User?
    let apiService: GitHubAPIService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let author = author {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(author.login)
                            .font(.headline)
                    }
                }

                Spacer()

                Text("Description")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Use GitHub markdown rendering
            MarkdownRenderView(markdown: bodyText, apiService: apiService)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
        }
    }
}

// MARK: - Comments Section
struct CommentsSection: View {
    let comments: [Comment]
    let isLoading: Bool
    let apiService: GitHubAPIService
    let onAddComment: () -> Void
    let onEditComment: (Comment) -> Void
    let onDeleteComment: (Comment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left")
                    .foregroundColor(.secondary)
                Text("Comments")
                    .font(.headline)
                Text("(\(comments.count))")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            if isLoading {
                ProgressView("Loading comments...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if comments.isEmpty {
                Text("No comments yet")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                ForEach(comments) { comment in
                    CommentView(
                        comment: comment,
                        apiService: apiService,
                        onEdit: {
                            onEditComment(comment)
                        },
                        onDelete: {
                            onDeleteComment(comment)
                        }
                    )
                }
            }

            // Add comment button
            Button {
                onAddComment()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Add Comment")
                        .font(.subheadline)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}

// MARK: - Comment View
struct CommentView: View {
    let comment: Comment
    let apiService: GitHubAPIService
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.accentColor)

                if let author = comment.author {
                    Text(author.login)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text("Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                Text("commented")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(comment.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Edit button
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit comment")

                // Delete button
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete comment")
            }

            // Use GitHub markdown rendering
            MarkdownRenderView(markdown: comment.body, apiService: apiService)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout for Labels
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
