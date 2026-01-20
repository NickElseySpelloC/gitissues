//
//  Repository.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

struct Repository: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let owner: User
    let isPrivate: Bool

    var fullName: String {
        "\(owner.login)/\(name)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case owner
        case isPrivate
    }
}
