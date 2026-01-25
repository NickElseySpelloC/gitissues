//
//  WindowModels.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

// MARK: - Window Identifier

enum WindowIdentifier: String {
    case issueForm = "issueForm"
    case commentForm = "commentForm"
}

// MARK: - Issue Form Window Data

struct IssueFormWindowData: Hashable, Codable {
    let id: UUID
    let mode: Mode
    let accessToken: String
    let issueData: IssueData?

    enum Mode: String, Hashable, Codable {
        case create
        case edit
    }

    struct IssueData: Hashable, Codable {
        let issueId: String
        let title: String
        let body: String?
        let state: String
        let repositoryId: String
        let repositoryOwner: String
        let repositoryName: String
        let labelIds: [String]
    }

    init(id: UUID = UUID(), mode: Mode, accessToken: String, issueData: IssueData? = nil) {
        self.id = id
        self.mode = mode
        self.accessToken = accessToken
        self.issueData = issueData
    }
}

// MARK: - Comment Form Window Data

struct CommentFormWindowData: Hashable, Codable {
    let id: UUID
    let mode: Mode
    let accessToken: String
    let issueId: String
    let issueState: String
    let commentData: CommentData?

    enum Mode: String, Hashable, Codable {
        case add
        case edit
    }

    struct CommentData: Hashable, Codable {
        let commentId: String
        let body: String
    }

    init(
        id: UUID = UUID(),
        mode: Mode,
        accessToken: String,
        issueId: String,
        issueState: String,
        commentData: CommentData? = nil
    ) {
        self.id = id
        self.mode = mode
        self.accessToken = accessToken
        self.issueId = issueId
        self.issueState = issueState
        self.commentData = commentData
    }
}
