//
//  GitHubAPIService.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

class GitHubAPIService {
    private let graphQLClient: GraphQLClient

    init(accessToken: String) {
        self.graphQLClient = GraphQLClient(accessToken: accessToken)
    }

    /// Fetches all issues for the authenticated user
    /// - Parameters:
    ///   - states: Filter by issue state (open, closed, or nil for all)
    ///   - cursor: Pagination cursor for fetching next page
    /// - Returns: Array of issues and pagination info
    func fetchIssues(
        states: [IssueState]? = nil,
        cursor: String? = nil
    ) async throws -> (issues: [Issue], hasNextPage: Bool, endCursor: String?) {
        var variables: [String: Any] = [:]

        if let states = states {
            variables["states"] = states.map { $0.rawValue }
        }

        if let cursor = cursor {
            variables["cursor"] = cursor
        }

        let response: AllIssuesResponse = try await graphQLClient.execute(
            query: GraphQLQueries.allIssuesQuery,
            variables: variables.isEmpty ? nil : variables
        )

        let issues = response.viewer.issues.nodes.map { $0.toIssue() }
        let pageInfo = response.viewer.issues.pageInfo

        return (issues, pageInfo.hasNextPage, pageInfo.endCursor)
    }

    /// Fetches all issues across all pages
    /// - Parameter states: Filter by issue state (open, closed, or nil for all)
    /// - Returns: Array of all issues
    func fetchAllIssues(states: [IssueState]? = nil) async throws -> [Issue] {
        var allIssues: [Issue] = []
        var cursor: String? = nil
        var hasNextPage = true

        while hasNextPage {
            let (issues, nextPage, nextCursor) = try await fetchIssues(
                states: states,
                cursor: cursor
            )

            allIssues.append(contentsOf: issues)
            hasNextPage = nextPage
            cursor = nextCursor
        }

        return allIssues
    }

    /// Fetches a specific issue with its comments
    /// - Parameters:
    ///   - owner: Repository owner login
    ///   - repo: Repository name
    ///   - number: Issue number
    /// - Returns: Issue and its comments
    func fetchIssueDetail(
        owner: String,
        repo: String,
        number: Int
    ) async throws -> (issue: Issue, comments: [Comment]) {
        let variables: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "number": number
        ]

        let response: IssueDetailResponse = try await graphQLClient.execute(
            query: GraphQLQueries.issueDetailQuery,
            variables: variables
        )

        let issue = response.repository.issue.toIssue()
        let comments = response.repository.issue.toComments()

        return (issue, comments)
    }

    /// Creates a new issue in a repository
    /// - Parameters:
    ///   - repositoryId: The ID of the repository
    ///   - title: The issue title
    ///   - body: The issue body (optional)
    /// - Returns: The created Issue
    func createIssue(
        repositoryId: String,
        title: String,
        body: String?
    ) async throws -> Issue {
        // Validate inputs
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NSError(domain: "GitHubAPIService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Title cannot be empty"
            ])
        }

        // Prepare body - convert empty string to nil
        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalBody = (trimmedBody?.isEmpty ?? true) ? nil : trimmedBody

        var variables: [String: Any] = [
            "repositoryId": repositoryId,
            "title": trimmedTitle
        ]

        if let finalBody = finalBody {
            variables["body"] = finalBody
        }

        let response: CreateIssueResponse = try await graphQLClient.execute(
            query: GraphQLQueries.createIssueMutation,
            variables: variables
        )

        return response.createIssue.issue.toIssue()
    }

    /// Updates an existing issue
    /// - Parameters:
    ///   - issueId: The ID of the issue to update
    ///   - title: The new title (optional)
    ///   - body: The new body (optional)
    ///   - state: The new state (optional)
    /// - Returns: The updated Issue
    func updateIssue(
        issueId: String,
        title: String?,
        body: String?,
        state: IssueState?
    ) async throws -> Issue {
        var variables: [String: Any] = ["id": issueId]

        // Validate and add title if provided
        if let title = title {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else {
                throw NSError(domain: "GitHubAPIService", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Title cannot be empty"
                ])
            }
            variables["title"] = trimmedTitle
        }

        // Add body if provided (convert empty to nil)
        if let body = body {
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalBody = trimmedBody.isEmpty ? nil : trimmedBody
            variables["body"] = finalBody
        }

        // Add state if provided
        if let state = state {
            variables["state"] = state.rawValue
        }

        let response: UpdateIssueResponse = try await graphQLClient.execute(
            query: GraphQLQueries.updateIssueMutation,
            variables: variables
        )

        return response.updateIssue.issue.toIssue()
    }

    /// Adds a comment to an issue
    /// - Parameters:
    ///   - issueId: The ID of the issue to comment on
    ///   - body: The comment body
    /// - Returns: The created Comment
    func addComment(
        issueId: String,
        body: String
    ) async throws -> Comment {
        // Validate inputs
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            throw NSError(domain: "GitHubAPIService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Comment cannot be empty"
            ])
        }

        let variables: [String: Any] = [
            "subjectId": issueId,
            "body": trimmedBody
        ]

        let response: AddCommentResponse = try await graphQLClient.execute(
            query: GraphQLQueries.addCommentMutation,
            variables: variables
        )

        return response.addComment.commentEdge.node.toComment()
    }

    /// Updates an existing comment
    /// - Parameters:
    ///   - commentId: The ID of the comment to update
    ///   - body: The new comment body
    /// - Returns: The updated Comment
    func updateComment(
        commentId: String,
        body: String
    ) async throws -> Comment {
        // Validate inputs
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            throw NSError(domain: "GitHubAPIService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Comment cannot be empty"
            ])
        }

        let variables: [String: Any] = [
            "id": commentId,
            "body": trimmedBody
        ]

        let response: UpdateCommentResponse = try await graphQLClient.execute(
            query: GraphQLQueries.updateCommentMutation,
            variables: variables
        )

        return response.updateIssueComment.issueComment.toComment()
    }

    /// Deletes a comment
    /// - Parameter commentId: The ID of the comment to delete
    func deleteComment(commentId: String) async throws {
        let variables: [String: Any] = [
            "id": commentId
        ]

        let _: DeleteCommentResponse = try await graphQLClient.execute(
            query: GraphQLQueries.deleteCommentMutation,
            variables: variables
        )
    }
}
