//
//  Issue.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

enum IssueState: String, Codable {
    case open = "OPEN"
    case closed = "CLOSED"
}

struct Issue: Codable, Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let body: String?
    let state: IssueState
    let createdAt: Date
    let updatedAt: Date
    let repository: Repository
    let labels: [Label]
    let assignees: [User]
    let author: User?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case body
        case state
        case createdAt
        case updatedAt
        case repository
        case labels
        case assignees
        case author
    }

    /// The repository's full name, with a " (read-only)" suffix when the repo is archived or the
    /// viewer lacks write access — used for display in the issue list and kanban cards.
    var repositoryDisplayName: String {
        repository.isReadOnly ? "\(repository.fullName) (read-only)" : repository.fullName
    }
}
