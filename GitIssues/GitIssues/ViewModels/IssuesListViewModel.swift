//
//  IssuesListViewModel.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class IssuesListViewModel: ObservableObject {
    @Published var allIssues: [Issue] = []
    @Published var filteredIssues: [Issue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filterOptions = FilterOptions()
    @Published var pinnedIssueIDs: Set<String> = []

    private let apiService: GitHubAPIService
    let pinningService: PinningService // Made public so detail view can access it
    private var cancellables = Set<AnyCancellable>()

    init(accessToken: String) {
        self.apiService = GitHubAPIService(accessToken: accessToken)
        self.pinningService = PinningService()
        self.pinnedIssueIDs = pinningService.getPinnedIssues()

        // Observe filter changes and refilter
        Publishers.CombineLatest3($filterOptions, $allIssues, $pinnedIssueIDs)
            .map { filterOptions, allIssues, pinnedIDs in
                Self.applyFiltersAndSort(filterOptions: filterOptions, to: allIssues, pinnedIDs: pinnedIDs)
            }
            .assign(to: &$filteredIssues)
    }

    /// Loads issues from the API
    func loadIssues() async {
        print("DEBUG: Starting loadIssues()")
        isLoading = true
        errorMessage = nil

        do {
            print("DEBUG: Fetching issues with states: \(String(describing: filterOptions.stateFilter.issueStates))")
            let issues = try await apiService.fetchAllIssues(states: filterOptions.stateFilter.issueStates)
            print("DEBUG: Fetched \(issues.count) issues")
            self.allIssues = issues
            self.isLoading = false
            print("DEBUG: loadIssues() completed successfully")
        } catch {
            print("DEBUG: Error loading issues: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    /// Applies filters and sorting to issues
    private static func applyFiltersAndSort(filterOptions: FilterOptions, to issues: [Issue], pinnedIDs: Set<String>) -> [Issue] {
        print("DEBUG: applyFiltersAndSort called with \(issues.count) issues")
        // Filter issues
        let filtered = issues.filter { filterOptions.matches(issue: $0) }
        print("DEBUG: After filtering: \(filtered.count) issues")

        // Sort issues
        let sorted = filterOptions.sortOption.sort(filtered)

        // Separate pinned and unpinned
        let pinned = sorted.filter { pinnedIDs.contains($0.id) }
        let unpinned = sorted.filter { !pinnedIDs.contains($0.id) }

        // Return pinned first, then unpinned
        return pinned + unpinned
    }

    /// Toggles the pinned state of an issue
    func togglePin(for issueID: String) {
        pinningService.togglePin(issueID)
        pinnedIssueIDs = pinningService.getPinnedIssues()
    }

    /// Checks if an issue is pinned
    func isPinned(_ issueID: String) -> Bool {
        return pinnedIssueIDs.contains(issueID)
    }

    /// Gets all unique repositories from the issues list
    var availableRepositories: [Repository] {
        let repos = allIssues.map { $0.repository }
        let uniqueRepos = Dictionary(grouping: repos, by: { $0.id })
            .compactMap { $0.value.first }
        return uniqueRepos.sorted { $0.fullName < $1.fullName }
    }

    /// Updates the state filter
    func setStateFilter(_ filter: IssueStateFilter) {
        filterOptions.stateFilter = filter

        // Reload issues with new state filter
        Task {
            await loadIssues()
        }
    }

    /// Updates the visibility filter
    func setVisibilityFilter(_ filter: VisibilityFilter) {
        print("DEBUG: setVisibilityFilter called with \(filter)")
        var options = filterOptions
        options.visibilityFilter = filter
        filterOptions = options
        print("DEBUG: filterOptions updated, filtered issues count: \(filteredIssues.count)")
    }

    /// Updates the sort option
    func setSortOption(_ option: SortOption) {
        print("DEBUG: setSortOption called with \(option.displayName)")
        var options = filterOptions
        options.sortOption = option
        filterOptions = options
        print("DEBUG: filterOptions updated, filtered issues count: \(filteredIssues.count)")
    }

    /// Updates the search text
    func setSearchText(_ text: String) {
        var options = filterOptions
        options.searchText = text
        filterOptions = options
    }

    /// Toggles repository selection
    func toggleRepository(_ repositoryID: String) {
        print("DEBUG: toggleRepository called with \(repositoryID)")
        var options = filterOptions
        if options.selectedRepositories.contains(repositoryID) {
            options.selectedRepositories.remove(repositoryID)
            print("DEBUG: Removed repo, now \(options.selectedRepositories.count) selected")
        } else {
            options.selectedRepositories.insert(repositoryID)
            print("DEBUG: Added repo, now \(options.selectedRepositories.count) selected")
        }
        filterOptions = options
        print("DEBUG: filterOptions updated, filtered issues count: \(filteredIssues.count)")
    }

    /// Clears all repository filters
    func clearRepositoryFilter() {
        var options = filterOptions
        options.selectedRepositories.removeAll()
        filterOptions = options
    }
}
