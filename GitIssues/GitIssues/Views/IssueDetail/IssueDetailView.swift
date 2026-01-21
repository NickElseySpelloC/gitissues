//
//  IssueDetailView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct IssueDetailView: View {
    @StateObject var viewModel: IssueDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                IssueHeaderView(issue: viewModel.issue, isPinned: viewModel.isPinned()) {
                    viewModel.togglePin()
                }

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
                    IssueBodyView(bodyText: body, author: viewModel.issue.author)
                } else {
                    Text("No description provided")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                }

                // Comments section
                CommentsSection(
                    comments: viewModel.comments,
                    isLoading: viewModel.isLoadingComments
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
        }
    }
}

// MARK: - Issue Header
struct IssueHeaderView: View {
    let issue: Issue
    let isPinned: Bool
    let onPinToggle: () -> Void

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

                // Pin button
                Button(action: onPinToggle) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.title2)
                        .foregroundColor(isPinned ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin issue" : "Pin issue")
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

            // Use markdown rendering
            Text(.init(bodyText))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
        }
    }
}

// MARK: - Comments Section
struct CommentsSection: View {
    let comments: [Comment]
    let isLoading: Bool

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
                    CommentView(comment: comment)
                }
            }
        }
    }
}

// MARK: - Comment View
struct CommentView: View {
    let comment: Comment

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
            }

            Text(.init(comment.body))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
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
