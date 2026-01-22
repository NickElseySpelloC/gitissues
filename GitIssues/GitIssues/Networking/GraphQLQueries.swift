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

    /// Query to fetch a specific issue with its comments
    static let issueDetailQuery = """
    query IssueDetail($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
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
          labels(first: 20) {
            nodes {
              id
              name
              color
            }
          }
          assignees(first: 20) {
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
          comments(first: 100) {
            nodes {
              id
              body
              createdAt
              updatedAt
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
    }
    """

    /// Mutation to create a new issue
    static let createIssueMutation = """
    mutation CreateIssue($repositoryId: ID!, $title: String!, $body: String) {
      createIssue(input: {repositoryId: $repositoryId, title: $title, body: $body}) {
        issue {
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
    """

    /// Mutation to update an existing issue
    static let updateIssueMutation = """
    mutation UpdateIssue($id: ID!, $title: String, $body: String, $state: IssueState) {
      updateIssue(input: {id: $id, title: $title, body: $body, state: $state}) {
        issue {
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
    """

    /// Mutation to add a comment to an issue
    static let addCommentMutation = """
    mutation AddComment($subjectId: ID!, $body: String!) {
      addComment(input: {subjectId: $subjectId, body: $body}) {
        commentEdge {
          node {
            id
            body
            createdAt
            updatedAt
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

    /// Mutation to update a comment
    static let updateCommentMutation = """
    mutation UpdateComment($id: ID!, $body: String!) {
      updateIssueComment(input: {id: $id, body: $body}) {
        issueComment {
          id
          body
          createdAt
          updatedAt
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
    """

    /// Mutation to delete a comment
    static let deleteCommentMutation = """
    mutation DeleteComment($id: ID!) {
      deleteIssueComment(input: {id: $id}) {
        clientMutationId
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

// Response structure for issue detail query
struct IssueDetailResponse: Codable {
    let repository: RepositoryDetail

    struct RepositoryDetail: Codable {
        let issue: IssueDetailNode
    }

    struct IssueDetailNode: Codable {
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
        let comments: CommentsConnection

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

        func toComments() -> [Comment] {
            comments.nodes.map { $0.toComment() }
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

    struct CommentsConnection: Codable {
        let nodes: [CommentNode]
    }

    struct CommentNode: Codable {
        let id: String
        let body: String
        let createdAt: Date
        let updatedAt: Date
        let author: CommentAuthorNode?

        func toComment() -> Comment {
            Comment(
                id: id,
                body: body,
                author: author?.toUser(),
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    struct CommentAuthorNode: Codable {
        let id: String
        let login: String
        let avatarUrl: String?

        func toUser() -> User {
            User(id: id, login: login, avatarUrl: avatarUrl)
        }
    }
}

// Response structure for create issue mutation
struct CreateIssueResponse: Codable {
    let createIssue: CreateIssuePayload

    struct CreateIssuePayload: Codable {
        let issue: IssueNode
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

// Response structure for update issue mutation
struct UpdateIssueResponse: Codable {
    let updateIssue: UpdateIssuePayload

    struct UpdateIssuePayload: Codable {
        let issue: IssueNode
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

// Response structure for add comment mutation
struct AddCommentResponse: Codable {
    let addComment: AddCommentPayload

    struct AddCommentPayload: Codable {
        let commentEdge: CommentEdge
    }

    struct CommentEdge: Codable {
        let node: CommentNode
    }

    struct CommentNode: Codable {
        let id: String
        let body: String
        let createdAt: Date
        let updatedAt: Date
        let author: AuthorNode?

        func toComment() -> Comment {
            Comment(
                id: id,
                body: body,
                author: author?.toUser(),
                createdAt: createdAt,
                updatedAt: updatedAt
            )
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

// Response structure for update comment mutation
struct UpdateCommentResponse: Codable {
    let updateIssueComment: UpdateIssueCommentPayload

    struct UpdateIssueCommentPayload: Codable {
        let issueComment: CommentNode
    }

    struct CommentNode: Codable {
        let id: String
        let body: String
        let createdAt: Date
        let updatedAt: Date
        let author: AuthorNode?

        func toComment() -> Comment {
            Comment(
                id: id,
                body: body,
                author: author?.toUser(),
                createdAt: createdAt,
                updatedAt: updatedAt
            )
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

// Response structure for delete comment mutation
struct DeleteCommentResponse: Codable {
    let deleteIssueComment: DeleteIssueCommentPayload

    struct DeleteIssueCommentPayload: Codable {
        let clientMutationId: String?
    }
}
