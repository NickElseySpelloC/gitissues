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
}
