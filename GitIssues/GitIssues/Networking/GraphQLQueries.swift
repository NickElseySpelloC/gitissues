//
//  GraphQLQueries.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

struct GraphQLQueries {
    /// Query to fetch all issues for the authenticated user
    static let allIssuesQuery = """
    query AllIssues($cursor: String, $states: [IssueState!], $first: Int = 50) {
      viewer {
        issues(first: $first, after: $cursor, states: $states, orderBy: {field: UPDATED_AT, direction: DESC}) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            number
            title
            body
            state
            createdAt
            updatedAt
            repository {
              id
              name
              owner {
                id
                login
                avatarUrl
              }
              isPrivate
            }
            labels(first: 10) {
              nodes {
                id
                name
                color
              }
            }
            assignees(first: 10) {
              nodes {
                id
                login
                avatarUrl
              }
            }
            author {
              ... on User {
                id
                login
                avatarUrl
              }
            }
          }
        }
      }
    }
    """
}

// Response structures for GraphQL queries
struct AllIssuesResponse: Codable {
    let viewer: Viewer

    struct Viewer: Codable {
        let issues: IssuesConnection
    }

    struct IssuesConnection: Codable {
        let pageInfo: PageInfo
        let nodes: [IssueNode]
    }

    struct PageInfo: Codable {
        let hasNextPage: Bool
        let endCursor: String?
    }

    struct IssueNode: Codable {
        let id: String
        let number: Int
        let title: String
        let body: String?
        let state: IssueState
        let createdAt: Date
        let updatedAt: Date
        let repository: RepositoryNode
        let labels: LabelsConnection
        let assignees: AssigneesConnection
        let author: AuthorNode?

        func toIssue() -> Issue {
            Issue(
                id: id,
                number: number,
                title: title,
                body: body,
                state: state,
                createdAt: createdAt,
                updatedAt: updatedAt,
                repository: repository.toRepository(),
                labels: labels.nodes.map { $0.toLabel() },
                assignees: assignees.nodes.map { $0.toUser() },
                author: author?.toUser()
            )
        }
    }

    struct RepositoryNode: Codable {
        let id: String
        let name: String
        let owner: OwnerNode
        let isPrivate: Bool

        func toRepository() -> Repository {
            Repository(
                id: id,
                name: name,
                owner: owner.toUser(),
                isPrivate: isPrivate
            )
        }
    }

    struct OwnerNode: Codable {
        let id: String
        let login: String
        let avatarUrl: String?

        func toUser() -> User {
            User(id: id, login: login, avatarUrl: avatarUrl)
        }
    }

    struct LabelsConnection: Codable {
        let nodes: [LabelNode]
    }

    struct LabelNode: Codable {
        let id: String
        let name: String
        let color: String

        func toLabel() -> Label {
            Label(id: id, name: name, color: color)
        }
    }

    struct AssigneesConnection: Codable {
        let nodes: [AssigneeNode]
    }

    struct AssigneeNode: Codable {
        let id: String
        let login: String
        let avatarUrl: String?

        func toUser() -> User {
            User(id: id, login: login, avatarUrl: avatarUrl)
        }
    }

    struct AuthorNode: Codable {
        let id: String
        let login: String
        let avatarUrl: String?

        func toUser() -> User {
            User(id: id, login: login, avatarUrl: avatarUrl)
        }
    }
}
