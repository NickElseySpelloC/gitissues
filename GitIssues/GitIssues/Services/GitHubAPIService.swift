//
//  GitHubAPIService.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

class GitHubAPIService {
    private let graphQLClient: GraphQLClient
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
        self.graphQLClient = GraphQLClient(accessToken: accessToken)
    }

    /// Fetches the authenticated user's login
    /// - Returns: The viewer's GitHub login
    func fetchViewerLogin() async throws -> String {
        let response: ViewerResponse = try await graphQLClient.execute(
            query: GraphQLQueries.viewerQuery,
            variables: nil
        )
        return response.viewer.login
    }

    /// Fetches all issues involving the authenticated user using search
    /// - Parameters:
    ///   - states: Filter by issue state (open, closed, or nil for all)
    ///   - repositoryFullNames: Filter by specific repositories (e.g., ["owner/repo1", "owner/repo2"])
    ///   - visibility: Filter by repository visibility (public, private, or nil for all)
    ///   - cursor: Pagination cursor for fetching next page
    /// - Returns: Array of issues and pagination info
    func fetchIssues(
        states: [IssueState]? = nil,
        repositoryFullNames: [String]? = nil,
        visibility: String? = nil,
        cursor: String? = nil
    ) async throws -> (issues: [Issue], hasNextPage: Bool, endCursor: String?) {
        // Build search query string
        var queryParts = ["involves:@me", "sort:updated-desc"]

        // Add state filter
        if let states = states {
            let stateStrings = states.map { state -> String in
                switch state {
                case .open: return "is:open"
                case .closed: return "is:closed"
                }
            }
            if stateStrings.count == 1 {
                queryParts.append(stateStrings[0])
            }
            // If both open and closed, don't add state filter (shows all)
        }

        // Add repository filter
        if let repos = repositoryFullNames, !repos.isEmpty {
            let repoQuery = repos.map { "repo:\($0)" }.joined(separator: " ")
            queryParts.append(repoQuery)
        }

        // Add visibility filter
        if let visibility = visibility {
            queryParts.append("is:\(visibility)")
        }

        let searchQuery = queryParts.joined(separator: " ")

        var variables: [String: Any] = ["query": searchQuery]

        if let cursor = cursor {
            variables["cursor"] = cursor
        }

        let response: AllIssuesResponse = try await graphQLClient.execute(
            query: GraphQLQueries.allIssuesQuery,
            variables: variables
        )

        let issues = response.search.nodes.map { $0.toIssue() }
        let pageInfo = response.search.pageInfo

        return (issues, pageInfo.hasNextPage, pageInfo.endCursor)
    }

    /// Fetches all issues across all pages
    /// - Parameters:
    ///   - states: Filter by issue state (open, closed, or nil for all)
    ///   - repositoryFullNames: Filter by specific repositories (e.g., ["owner/repo1", "owner/repo2"])
    ///   - visibility: Filter by repository visibility (public, private, or nil for all)
    /// - Returns: Array of all issues
    func fetchAllIssues(
        states: [IssueState]? = nil,
        repositoryFullNames: [String]? = nil,
        visibility: String? = nil
    ) async throws -> [Issue] {
        var allIssues: [Issue] = []
        var cursor: String? = nil
        var hasNextPage = true

        while hasNextPage {
            let (issues, nextPage, nextCursor) = try await fetchIssues(
                states: states,
                repositoryFullNames: repositoryFullNames,
                visibility: visibility,
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
    ///   - labelIds: Array of label IDs to add (optional)
    /// - Returns: The created Issue
    func createIssue(
        repositoryId: String,
        title: String,
        body: String?,
        labelIds: [String]? = nil
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

        if let labelIds = labelIds, !labelIds.isEmpty {
            variables["labelIds"] = labelIds
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

    /// Fetches all repositories owned by the authenticated user
    /// - Parameter cursor: Pagination cursor for fetching next page
    /// - Returns: Array of repositories and pagination info
    func fetchRepositories(cursor: String? = nil) async throws -> (repositories: [Repository], hasNextPage: Bool, endCursor: String?) {
        var variables: [String: Any] = [:]

        if let cursor = cursor {
            variables["cursor"] = cursor
        }

        let response: RepositoriesResponse = try await graphQLClient.execute(
            query: GraphQLQueries.repositoriesQuery,
            variables: variables
        )

        let repositories = response.viewer.repositories.nodes.map { $0.toRepository() }
        let pageInfo = response.viewer.repositories.pageInfo

        return (repositories, pageInfo.hasNextPage, pageInfo.endCursor)
    }

    /// Fetches all repositories across all pages
    /// - Returns: Array of all repositories
    func fetchAllRepositories() async throws -> [Repository] {
        var allRepositories: [Repository] = []
        var cursor: String? = nil
        var hasNextPage = true

        while hasNextPage {
            let (repositories, nextPage, nextCursor) = try await fetchRepositories(cursor: cursor)
            allRepositories.append(contentsOf: repositories)
            hasNextPage = nextPage
            cursor = nextCursor
        }

        return allRepositories
    }

    /// Deletes an issue
    /// - Parameter issueId: The ID of the issue to delete
    func deleteIssue(issueId: String) async throws {
        let variables: [String: Any] = [
            "id": issueId
        ]

        let _: DeleteIssueResponse = try await graphQLClient.execute(
            query: GraphQLQueries.deleteIssueMutation,
            variables: variables
        )
    }

    /// Fetches labels for a repository
    /// - Parameters:
    ///   - owner: Repository owner login
    ///   - repo: Repository name
    ///   - cursor: Pagination cursor
    /// - Returns: Array of labels and pagination info
    func fetchRepositoryLabels(owner: String, repo: String, cursor: String? = nil) async throws -> (labels: [Label], hasNextPage: Bool, endCursor: String?) {
        var variables: [String: Any] = [
            "owner": owner,
            "repo": repo
        ]

        if let cursor = cursor {
            variables["cursor"] = cursor
        }

        let response: RepositoryLabelsResponse = try await graphQLClient.execute(
            query: GraphQLQueries.repositoryLabelsQuery,
            variables: variables
        )

        let labels = response.repository.labels.nodes.map { $0.toLabel() }
        let pageInfo = response.repository.labels.pageInfo

        return (labels, pageInfo.hasNextPage, pageInfo.endCursor)
    }

    /// Fetches all labels for a repository across all pages
    /// - Parameters:
    ///   - owner: Repository owner login
    ///   - repo: Repository name
    /// - Returns: Array of all labels
    func fetchAllRepositoryLabels(owner: String, repo: String) async throws -> [Label] {
        var allLabels: [Label] = []
        var cursor: String? = nil
        var hasNextPage = true

        while hasNextPage {
            let (labels, nextPage, nextCursor) = try await fetchRepositoryLabels(
                owner: owner,
                repo: repo,
                cursor: cursor
            )
            allLabels.append(contentsOf: labels)
            hasNextPage = nextPage
            cursor = nextCursor
        }

        return allLabels
    }

    /// Adds labels to an issue
    /// - Parameters:
    ///   - issueId: The ID of the issue
    ///   - labelIds: Array of label IDs to add
    func addLabelsToIssue(issueId: String, labelIds: [String]) async throws {
        let variables: [String: Any] = [
            "issueId": issueId,
            "labelIds": labelIds
        ]

        let _: AddLabelsResponse = try await graphQLClient.execute(
            query: GraphQLQueries.addLabelsToIssueMutation,
            variables: variables
        )
    }

    /// Removes labels from an issue
    /// - Parameters:
    ///   - issueId: The ID of the issue
    ///   - labelIds: Array of label IDs to remove
    func removeLabelsFromIssue(issueId: String, labelIds: [String]) async throws {
        let variables: [String: Any] = [
            "issueId": issueId,
            "labelIds": labelIds
        ]

        let _: RemoveLabelsResponse = try await graphQLClient.execute(
            query: GraphQLQueries.removeLabelsFromIssueMutation,
            variables: variables
        )
    }

    /// Renders markdown text to HTML using GitHub's rendering API
    /// - Parameter markdown: The markdown text to render
    /// - Returns: Rendered HTML string
    func renderMarkdown(_ markdown: String) async throws -> String {
        guard let url = URL(string: "https://api.github.com/markdown") else {
            throw NSError(domain: "GitHubAPIService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URL"
            ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": markdown,
            "mode": "gfm"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "GitHubAPIService", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode HTML response"
            ])
        }

        return html
    }
}
