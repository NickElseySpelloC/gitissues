//
//  GraphQLQueries.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

struct GraphQLQueries {
    /// Query to fetch the authenticated user's login
    static let viewerQuery = """
    query Viewer {
      viewer {
        login
      }
    }
    """

    /// Query to fetch all issues involving the authenticated user using search
    static let allIssuesQuery = """
    query AllIssues($query: String!, $cursor: String, $first: Int = 50) {
      search(query: $query, type: ISSUE, first: $first, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          ... on Issue {
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
                ... on User {
                  id
                  login
                  avatarUrl
                }
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
              ... on User {
                id
                login
                avatarUrl
              }
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

    /// Query to fetch all repositories owned by the user
    static let repositoriesQuery = """
    query Repositories($cursor: String, $first: Int = 100) {
      viewer {
        repositories(first: $first, after: $cursor, ownerAffiliations: OWNER, orderBy: {field: NAME, direction: ASC}) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            name
            owner {
              login
            }
            isPrivate
          }
        }
      }
    }
    """

    /// Query to fetch labels for a repository
    static let repositoryLabelsQuery = """
    query RepositoryLabels($owner: String!, $repo: String!, $cursor: String, $first: Int = 100) {
      repository(owner: $owner, name: $repo) {
        labels(first: $first, after: $cursor) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            name
            color
          }
        }
      }
    }
    """

    /// Mutation to create a new issue
    static let createIssueMutation = """
    mutation CreateIssue($repositoryId: ID!, $title: String!, $body: String, $labelIds: [ID!]) {
      createIssue(input: {repositoryId: $repositoryId, title: $title, body: $body, labelIds: $labelIds}) {
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
              ... on User {
                id
                login
                avatarUrl
              }
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
              ... on User {
                id
                login
                avatarUrl
              }
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

    /// Mutation to delete an issue
    static let deleteIssueMutation = """
    mutation DeleteIssue($id: ID!) {
      deleteIssue(input: {issueId: $id}) {
        clientMutationId
      }
    }
    """

    /// Mutation to add labels to an issue
    static let addLabelsToIssueMutation = """
    mutation AddLabels($issueId: ID!, $labelIds: [ID!]!) {
      addLabelsToLabelable(input: {labelableId: $issueId, labelIds: $labelIds}) {
        clientMutationId
      }
    }
    """

    /// Mutation to remove labels from an issue
    static let removeLabelsFromIssueMutation = """
    mutation RemoveLabels($issueId: ID!, $labelIds: [ID!]!) {
      removeLabelsFromLabelable(input: {labelableId: $issueId, labelIds: $labelIds}) {
        clientMutationId
      }
    }
    """
}

// Response structures for GraphQL queries
struct AllIssuesResponse: Codable {
    let search: SearchConnection

    struct SearchConnection: Codable {
        let pageInfo: PageInfo
        let nodes: [IssueNode?]

        enum CodingKeys: String, CodingKey {
            case pageInfo
            case nodes
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pageInfo = try container.decode(PageInfo.self, forKey: .pageInfo)

            // Decode nodes array, gracefully handling empty objects from non-Issue types (like PRs)
            var nodesContainer = try container.nestedUnkeyedContainer(forKey: .nodes)
            var decodedNodes: [IssueNode?] = []

            while !nodesContainer.isAtEnd {
                // Try to decode each node, if it fails (empty object), append nil
                if let node = try? nodesContainer.decode(IssueNode.self) {
                    decodedNodes.append(node)
                } else {
                    // Skip the empty/invalid node
                    _ = try? nodesContainer.decode(AnyCodable.self)
                    decodedNodes.append(nil)
                }
            }

            nodes = decodedNodes
        }
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

// Response structure for delete issue mutation
struct DeleteIssueResponse: Codable {
    let deleteIssue: DeleteIssuePayload

    struct DeleteIssuePayload: Codable {
        let clientMutationId: String?
    }
}

// Response structure for viewer query
struct ViewerResponse: Codable {
    let viewer: ViewerNode

    struct ViewerNode: Codable {
        let login: String
    }
}

// Response structure for repositories query
struct RepositoriesResponse: Codable {
    let viewer: ViewerRepositories

    struct ViewerRepositories: Codable {
        let repositories: RepositoryConnection
    }

    struct RepositoryConnection: Codable {
        let pageInfo: PageInfo
        let nodes: [RepositoryNode]
    }

    struct PageInfo: Codable {
        let hasNextPage: Bool
        let endCursor: String?
    }

    struct RepositoryNode: Codable {
        let id: String
        let name: String
        let owner: OwnerNode
        let isPrivate: Bool

        func toRepository() -> Repository {
            return Repository(
                id: id,
                name: name,
                owner: User(
                    id: owner.login,
                    login: owner.login,
                    avatarUrl: ""
                ),
                isPrivate: isPrivate
            )
        }
    }

    struct OwnerNode: Codable {
        let login: String
    }
}

// Response structure for repository labels query
struct RepositoryLabelsResponse: Codable {
    let repository: RepositoryLabels

    struct RepositoryLabels: Codable {
        let labels: LabelConnection
    }

    struct LabelConnection: Codable {
        let pageInfo: PageInfo
        let nodes: [LabelNode]
    }

    struct PageInfo: Codable {
        let hasNextPage: Bool
        let endCursor: String?
    }

    struct LabelNode: Codable {
        let id: String
        let name: String
        let color: String

        func toLabel() -> Label {
            return Label(id: id, name: name, color: color)
        }
    }
}

// Response structure for add labels mutation
struct AddLabelsResponse: Codable {
    let addLabelsToLabelable: AddLabelsPayload

    struct AddLabelsPayload: Codable {
        let clientMutationId: String?
    }
}

// Response structure for remove labels mutation
struct RemoveLabelsResponse: Codable {
    let removeLabelsFromLabelable: RemoveLabelsPayload

    struct RemoveLabelsPayload: Codable {
        let clientMutationId: String?
    }
}
