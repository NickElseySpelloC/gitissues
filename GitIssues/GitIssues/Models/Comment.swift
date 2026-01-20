//
//  Comment.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

struct Comment: Codable, Identifiable {
    let id: String
    let body: String
    let author: User?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case body
        case author
        case createdAt
        case updatedAt
    }
}
