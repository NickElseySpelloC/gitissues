//
//  FilterOptions.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation

enum IssueStateFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case open = "Open"
    case closed = "Closed"

    var id: String { rawValue }

    var issueStates: [IssueState]? {
        switch self {
        case .all: return nil
        case .open: return [.open]
        case .closed: return [.closed]
        }
    }
}

enum VisibilityFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case publicRepos = "Public"
    case privateRepos = "Private"

    var id: String { rawValue }
}

enum SortOption: Identifiable {
    case createdAsc
    case createdDesc
    case updatedAsc
    case updatedDesc
    case numberAsc
    case numberDesc

    var id: String {
        switch self {
        case .createdAsc: return "created-asc"
        case .createdDesc: return "created-desc"
        case .updatedAsc: return "updated-asc"
        case .updatedDesc: return "updated-desc"
        case .numberAsc: return "number-asc"
        case .numberDesc: return "number-desc"
        }
    }

    var displayName: String {
        switch self {
        case .createdAsc: return "Created (Oldest)"
        case .createdDesc: return "Created (Newest)"
        case .updatedAsc: return "Updated (Oldest)"
        case .updatedDesc: return "Updated (Newest)"
        case .numberAsc: return "Issue # (Low to High)"
        case .numberDesc: return "Issue # (High to Low)"
        }
    }

    func sort(_ issues: [Issue]) -> [Issue] {
        switch self {
        case .createdAsc:
            return issues.sorted { $0.createdAt < $1.createdAt }
        case .createdDesc:
            return issues.sorted { $0.createdAt > $1.createdAt }
        case .updatedAsc:
            return issues.sorted { $0.updatedAt < $1.updatedAt }
        case .updatedDesc:
            return issues.sorted { $0.updatedAt > $1.updatedAt }
        case .numberAsc:
            return issues.sorted { $0.number < $1.number }
        case .numberDesc:
            return issues.sorted { $0.number > $1.number }
        }
    }
}

struct FilterOptions {
    var stateFilter: IssueStateFilter = .open
    var visibilityFilter: VisibilityFilter = .all
    var selectedRepositories: Set<String> = []
    var sortOption: SortOption = .updatedDesc
    var searchText: String = ""

    func matches(issue: Issue) -> Bool {
        // Check visibility filter
        print("DEBUG FilterOptions.matches: checking issue \(issue.number), repo isPrivate: \(issue.repository.isPrivate), visibilityFilter: \(visibilityFilter)")
        switch visibilityFilter {
        case .all:
            break
        case .publicRepos:
            if issue.repository.isPrivate {
                print("DEBUG: Filtering OUT private issue \(issue.number)")
                return false
            }
        case .privateRepos:
            if !issue.repository.isPrivate {
                print("DEBUG: Filtering OUT public issue \(issue.number)")
                return false
            }
        }

        // Check repository filter
        if !selectedRepositories.isEmpty {
            if !selectedRepositories.contains(issue.repository.id) {
                return false
            }
        }

        // Check search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let titleMatch = issue.title.lowercased().contains(searchLower)
            let bodyMatch = issue.body?.lowercased().contains(searchLower) ?? false
            let repoMatch = issue.repository.fullName.lowercased().contains(searchLower)

            if !titleMatch && !bodyMatch && !repoMatch {
                return false
            }
        }

        return true
    }
}
