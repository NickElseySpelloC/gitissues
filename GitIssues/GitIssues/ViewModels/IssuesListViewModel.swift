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
    @Published var viewerLogin: String?

    private let apiService: GitHubAPIService
    let pinningService: PinningService // Made public so detail view can access it
    private let appStateService = AppStateService()
    private var cancellables = Set<AnyCancellable>()

    init(accessToken: String) {
        self.apiService = GitHubAPIService(accessToken: accessToken)
        self.pinningService = PinningService()
        self.pinnedIssueIDs = pinningService.getPinnedIssues()

        // Restore saved filter state
        if let savedFilterOptions = appStateService.loadFilterState() {
            self.filterOptions = savedFilterOptions
        }

        // Observe filter changes and refilter
        Publishers.CombineLatest4($filterOptions, $allIssues, $pinnedIssueIDs, $viewerLogin)
            .map { filterOptions, allIssues, pinnedIDs, viewerLogin in
                Self.applyFiltersAndSort(filterOptions: filterOptions, to: allIssues, pinnedIDs: pinnedIDs, viewerLogin: viewerLogin)
            }
            .assign(to: &$filteredIssues)

        // Save filter state whenever it changes
        $filterOptions
            .dropFirst() // Skip initial value
            .sink { [weak self] newFilterOptions in
                self?.appStateService.saveFilterState(newFilterOptions)
            }
            .store(in: &cancellables)
    }

    /// Loads issues from the API with optional delay for GitHub sync
    func loadIssues(afterDelay delay: TimeInterval = 0) async {
        // Add delay if requested (for GitHub sync after create/delete)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        isLoading = true
        errorMessage = nil

        do {
            // Fetch viewer login if not already fetched
            if viewerLogin == nil {
                viewerLogin = try await apiService.fetchViewerLogin()
            }

            // Build visibility filter for server-side query
            var visibility: String? = nil
            switch filterOptions.visibilityFilter {
            case .all:
                visibility = nil
            case .publicRepos:
                visibility = "public"
            case .privateRepos:
                visibility = "private"
            }

            let issues = try await apiService.fetchAllIssues(
                states: filterOptions.stateFilter.issueStates,
                repositoryFullNames: nil, // Keep repository filtering client-side
                visibility: visibility
            )
            self.allIssues = issues
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    /// Applies filters and sorting to issues
    private static func applyFiltersAndSort(filterOptions: FilterOptions, to issues: [Issue], pinnedIDs: Set<String>, viewerLogin: String?) -> [Issue] {
        // Filter issues
        let filtered = issues.filter { filterOptions.matches(issue: $0, viewerLogin: viewerLogin) }

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
        filterOptions.visibilityFilter = filter

        // Reload issues with new visibility filter (server-side)
        Task {
            await loadIssues()
        }
    }

    /// Updates the involvement filter
    func setInvolvementFilter(_ filter: InvolvementFilter) {
        var options = filterOptions
        options.involvementFilter = filter
        filterOptions = options
    }

    /// Updates the sort option
    func setSortOption(_ option: SortOption) {
        var options = filterOptions
        options.sortOption = option
        filterOptions = options
    }

    /// Updates the search text
    func setSearchText(_ text: String) {
        var options = filterOptions
        options.searchText = text
        filterOptions = options
    }

    /// Toggles repository selection
    func toggleRepository(_ repositoryID: String) {
        var options = filterOptions
        if options.selectedRepositories.contains(repositoryID) {
            options.selectedRepositories.remove(repositoryID)
        } else {
            options.selectedRepositories.insert(repositoryID)
        }
        filterOptions = options
    }

    /// Clears all repository filters
    func clearRepositoryFilter() {
        var options = filterOptions
        options.selectedRepositories.removeAll()
        filterOptions = options
    }
}
