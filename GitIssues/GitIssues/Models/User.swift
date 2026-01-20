//
//  User.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: String
    let login: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl
    }
}
