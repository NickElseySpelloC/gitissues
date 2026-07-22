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
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var filterOptions = FilterOptions()
    @Published var pinnedIssueIDs: Set<String> = []
    @Published var viewerLogin: String?

    private let apiService: GitHubAPIService
    let pinningService: PinningService // Made public so detail view can access it
    private let appStateService = AppStateService()
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?

    // Track mutations that are ahead of any in-flight background sync
    private var pendingDeletions: Set<String> = []
    private var pendingInsertions: [Issue] = []

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

    /// Loads all issues from the API. Shows a full-screen spinner on first load;
    /// on subsequent loads keeps existing data visible while refreshing in the background.
    func loadIssues(afterDelay delay: TimeInterval = 0) async {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // First load: show full-screen spinner. Subsequent loads: keep list visible.
        if allIssues.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        do {
            // Fetch viewer login if not already fetched
            if viewerLogin == nil {
                viewerLogin = try await apiService.fetchViewerLogin()
            }

            // Fetch all issues regardless of state/visibility — filtering is done client-side
            let issues = try await apiService.fetchAllIssues()
            applyIssuesFromSync(issues)
            AppLogger.shared.info("Loaded \(issues.count) issues from GitHub")
        } catch {
            AppLogger.shared.error("Failed to load issues: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    // MARK: - Background Sync

    func startBackgroundSync() {
        stopBackgroundSync()
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let enabled = AppStateService.isSyncEnabled
                let interval = AppStateService.syncIntervalSeconds
                guard enabled, interval > 0 else {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self.syncIssuesSilently()
            }
        }
    }

    func stopBackgroundSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    private func syncIssuesSilently() async {
        guard !isLoading, !isRefreshing else { return }
        do {
            if viewerLogin == nil {
                viewerLogin = try await apiService.fetchViewerLogin()
            }
            let issues = try await apiService.fetchAllIssues()
            applyIssuesFromSync(issues)
        } catch {
            // Silent sync — don't surface transient errors
        }
    }

    /// Merges API-returned issues with any pending local mutations that may have raced ahead
    /// of an in-flight sync: re-injects unconfirmed insertions and filters out pending deletions.
    private func applyIssuesFromSync(_ issues: [Issue]) {
        let incomingIDs = Set(issues.map { $0.id })

        // Confirmed absent → deletion acknowledged, stop filtering
        pendingDeletions = pendingDeletions.filter { incomingIDs.contains($0) }
        // Confirmed present → insertion acknowledged, stop prepending
        pendingInsertions = pendingInsertions.filter { !incomingIDs.contains($0.id) }

        let filtered = issues.filter { !pendingDeletions.contains($0.id) }
        allIssues = pendingInsertions + filtered
    }

    // MARK: - Cache Mutations

    /// Inserts or updates an issue in the local cache without a full reload.
    /// If the issue already exists it is updated in place; otherwise it is inserted at the front.
    func upsertIssueInCache(_ issue: Issue) {
        if let index = allIssues.firstIndex(where: { $0.id == issue.id }) {
            allIssues[index] = issue
        } else {
            allIssues.insert(issue, at: 0)
            pendingInsertions.insert(issue, at: 0)
        }
    }

    /// Removes an issue from the local cache without a full reload.
    func removeIssueFromCache(id: String) {
        allIssues.removeAll { $0.id == id }
        pendingInsertions.removeAll { $0.id == id }
        pendingDeletions.insert(id)
    }

    /// Closes an issue via the API and immediately updates the local cache.
    func closeIssue(_ issue: Issue) async {
        do {
            let updatedIssue = try await apiService.updateIssue(issueId: issue.id, title: nil, body: nil, state: .closed)
            upsertIssueInCache(updatedIssue)
            AppLogger.shared.info("Closed issue #\(issue.number) (\(issue.repository.fullName))")
        } catch {
            AppLogger.shared.error("Failed to close issue #\(issue.number): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Reopens an issue via the API and immediately updates the local cache.
    func reopenIssue(_ issue: Issue) async {
        do {
            let updatedIssue = try await apiService.updateIssue(issueId: issue.id, title: nil, body: nil, state: .open)
            upsertIssueInCache(updatedIssue)
            AppLogger.shared.info("Reopened issue #\(issue.number) (\(issue.repository.fullName))")
        } catch {
            AppLogger.shared.error("Failed to reopen issue #\(issue.number): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes an issue via the API and immediately removes it from the local cache.
    func deleteIssue(_ issue: Issue) async {
        do {
            try await apiService.deleteIssue(issueId: issue.id)
            removeIssueFromCache(id: issue.id)
            AppLogger.shared.info("Deleted issue #\(issue.number) (\(issue.repository.fullName))")
        } catch {
            AppLogger.shared.error("Failed to delete issue #\(issue.number): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Updates assignees for an issue via the API and immediately updates the local cache.
    func assignIssue(_ issue: Issue, assignees: [User]) async {
        do {
            try await apiService.setIssueAssignees(
                issueId: issue.id,
                currentAssigneeIds: issue.assignees.map { $0.id },
                newAssigneeIds: assignees.map { $0.id }
            )
            let updated = Issue(
                id: issue.id,
                number: issue.number,
                title: issue.title,
                body: issue.body,
                state: issue.state,
                createdAt: issue.createdAt,
                updatedAt: issue.updatedAt,
                repository: issue.repository,
                labels: issue.labels,
                assignees: assignees,
                author: issue.author
            )
            upsertIssueInCache(updated)
            AppLogger.shared.info("Updated assignees for issue #\(issue.number) (\(assignees.count) assignee(s))")
        } catch {
            AppLogger.shared.error("Failed to assign issue #\(issue.number): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Clones an issue via the API and immediately adds the copy to the local cache.
    func cloneIssue(_ issue: Issue) async {
        do {
            let cloned = try await apiService.createIssue(
                repositoryId: issue.repository.id,
                title: issue.title + " copy",
                body: issue.body,
                labelIds: issue.labels.map { $0.id }
            )
            upsertIssueInCache(cloned)
            AppLogger.shared.info("Cloned issue #\(issue.number) (\(issue.repository.fullName)) to #\(cloned.number)")
        } catch {
            AppLogger.shared.error("Failed to clone issue #\(issue.number): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Kanban

    /// Transient status message for the Kanban board (e.g. an issue leaving the filtered view).
    /// Auto-clears after a few seconds.
    @Published var kanbanToastMessage: String?

    private func showKanbanToast(_ message: String) {
        kanbanToastMessage = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self?.kanbanToastMessage == message {
                self?.kanbanToastMessage = nil
            }
        }
    }

    /// Moves a single issue to a Kanban state (column) and sets its order key.
    ///
    /// The cache is updated **optimistically** so the card moves immediately; the GitHub API
    /// calls run afterwards and reconcile (or revert) in the background.
    func moveIssue(_ issue: Issue, to state: KanbanState, orderKey: String) async {
        let optimistic = makeOptimisticMove(issue, to: state, orderKey: orderKey)
        upsertIssueInCache(optimistic)
        if !filterOptions.matches(issue: optimistic, viewerLogin: viewerLogin) {
            showKanbanToast("#\(optimistic.number) → \(state.name) (hidden by current filter)")
        }
        await performKanbanMove(issue, to: state, orderKey: orderKey, revertTo: issue)
    }

    /// Moves several issues into a Kanban state, assigning the given consecutive order keys.
    /// All cards move optimistically first; the API work then reconciles in the background.
    func moveIssues(_ issues: [Issue], to state: KanbanState, orderKeys: [String]) async {
        var hidden = 0
        for (issue, key) in zip(issues, orderKeys) {
            let optimistic = makeOptimisticMove(issue, to: state, orderKey: key)
            upsertIssueInCache(optimistic)
            if !filterOptions.matches(issue: optimistic, viewerLogin: viewerLogin) {
                hidden += 1
            }
        }
        if hidden > 0 {
            showKanbanToast("\(hidden) issue\(hidden == 1 ? "" : "s") → \(state.name) (hidden by current filter)")
        }
        for (issue, key) in zip(issues, orderKeys) {
            await performKanbanMove(issue, to: state, orderKey: key, revertTo: issue)
        }
    }

    /// Builds a locally-updated copy of `issue` reflecting the move: managed Kanban labels swapped
    /// for the target's (unless it's the clutter-free default/closed state), the order marker set,
    /// and the open/closed state flipped to match the column. Used for the optimistic cache update;
    /// the real label IDs and body are reconciled once the API calls return.
    private func makeOptimisticMove(_ issue: Issue, to state: KanbanState, orderKey: String) -> Issue {
        let settings = KanbanSettingsService.shared
        let managed = settings.managedLabelNames
        var labels = issue.labels.filter { !managed.contains($0.name.lowercased()) }
        let isClutterFree = state.id == settings.defaultState.id || state.isClosed
        if !isClutterFree {
            labels.append(Label(
                id: "kanban-optimistic-\(state.id.uuidString)",
                name: Kanban.labelName(for: state),
                color: settings.color(for: state)
            ))
        }
        return Issue(
            id: issue.id,
            number: issue.number,
            title: issue.title,
            body: KanbanOrderMarker.inject(orderKey, into: issue.body),
            state: state.isClosed ? .closed : .open,
            createdAt: issue.createdAt,
            updatedAt: issue.updatedAt,
            repository: issue.repository,
            labels: labels,
            assignees: issue.assignees,
            author: issue.author
        )
    }

    /// Applies a Kanban move to GitHub, then upserts the canonical issue. Reverts to `original` on
    /// failure. Only labels matching a *configured* state are touched; other users' `kanban-*`
    /// labels are left intact.
    private func performKanbanMove(_ issue: Issue, to state: KanbanState, orderKey: String, revertTo original: Issue) async {
        let settings = KanbanSettingsService.shared
        do {
            // Fetch the latest issue so we act on current labels/body (minimises clobber).
            let (current, _) = try await apiService.fetchIssueDetail(
                owner: issue.repository.owner.login,
                repo: issue.repository.name,
                number: issue.number
            )

            // 1. Remove the managed Kanban labels currently on the issue.
            let managed = settings.managedLabelNames
            let labelsToRemove = current.labels.filter { managed.contains($0.name.lowercased()) }
            if !labelsToRemove.isEmpty {
                try await apiService.removeLabelsFromIssue(issueId: issue.id, labelIds: labelsToRemove.map { $0.id })
            }

            // 2. Add the target label unless this is the clutter-free default or closed state.
            let isClutterFree = state.id == settings.defaultState.id || state.isClosed
            if !isClutterFree {
                let label = try await apiService.ensureLabel(
                    in: issue.repository,
                    name: Kanban.labelName(for: state),
                    color: settings.color(for: state)
                )
                try await apiService.addLabelsToIssue(issueId: issue.id, labelIds: [label.id])
            }

            // 3. Write the order key into the body marker, and flip open/closed to match the column.
            let newState: IssueState? = (state.isClosed != (issue.state == .closed))
                ? (state.isClosed ? .closed : .open)
                : nil
            let newBody = KanbanOrderMarker.inject(orderKey, into: current.body)
            _ = try await apiService.updateIssue(issueId: issue.id, title: nil, body: newBody, state: newState)

            // 4. Re-fetch the canonical issue and reconcile the cache (real label IDs, etc.).
            let (updated, _) = try await apiService.fetchIssueDetail(
                owner: issue.repository.owner.login,
                repo: issue.repository.name,
                number: issue.number
            )
            upsertIssueInCache(updated)
            AppLogger.shared.info("Moved issue #\(issue.number) (\(issue.repository.fullName)) to kanban state '\(state.name)'")
        } catch {
            AppLogger.shared.error("Failed to move issue #\(issue.number) to '\(state.name)': \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            // Revert the optimistic change.
            upsertIssueInCache(original)
        }
    }

    // MARK: - Cross-Repository Transfer

    /// Fetches all repositories the user can transfer issues into.
    /// Falls back to the repositories already represented in the issues list on failure.
    func fetchSelectableRepositories() async -> [Repository] {
        do {
            return try await apiService.fetchAllRepositories()
        } catch {
            errorMessage = error.localizedDescription
            return availableRepositories
        }
    }

    /// Copies the given issues into the destination repository, updating the cache for each success.
    func copyIssues(_ issues: [Issue], to destination: Repository, progress: ((Int, Int) -> Void)? = nil) async -> TransferResult {
        AppLogger.shared.info("Copying \(issues.count) issue(s) to \(destination.fullName)")
        var succeeded = 0
        var failures: [(issue: Issue, message: String)] = []
        for (index, issue) in issues.enumerated() {
            do {
                let newIssue = try await apiService.copyIssue(issue, to: destination)
                upsertIssueInCache(newIssue)
                succeeded += 1
                AppLogger.shared.info("Copied issue #\(issue.number) (\(issue.repository.fullName)) to \(destination.fullName) #\(newIssue.number)")
            } catch {
                AppLogger.shared.error("Failed to copy issue #\(issue.number) to \(destination.fullName): \(error.localizedDescription)")
                failures.append((issue, error.localizedDescription))
            }
            progress?(index + 1, issues.count)
        }
        AppLogger.shared.info("Copy finished: \(succeeded) succeeded, \(failures.count) failed")
        return TransferResult(succeeded: succeeded, failures: failures)
    }

    /// Moves the given issues into the destination repository (preserving timestamps), updating
    /// the cache for each success: the new issue is inserted and the original removed.
    func moveIssues(_ issues: [Issue], to destination: Repository, progress: ((Int, Int) -> Void)? = nil) async -> TransferResult {
        AppLogger.shared.info("Moving \(issues.count) issue(s) to \(destination.fullName)")
        var succeeded = 0
        var failures: [(issue: Issue, message: String)] = []
        for (index, issue) in issues.enumerated() {
            do {
                let newIssue = try await apiService.moveIssue(issue, to: destination)
                removeIssueFromCache(id: issue.id)
                upsertIssueInCache(newIssue)
                succeeded += 1
                AppLogger.shared.info("Moved issue #\(issue.number) (\(issue.repository.fullName)) to \(destination.fullName) #\(newIssue.number)")
            } catch {
                AppLogger.shared.error("Failed to move issue #\(issue.number) to \(destination.fullName): \(error.localizedDescription)")
                failures.append((issue, error.localizedDescription))
            }
            progress?(index + 1, issues.count)
        }
        AppLogger.shared.info("Move finished: \(succeeded) succeeded, \(failures.count) failed")
        return TransferResult(succeeded: succeeded, failures: failures)
    }

    // MARK: - Filters

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

    /// Updates the state filter (client-side; no API call needed)
    func setStateFilter(_ filter: IssueStateFilter) {
        filterOptions.stateFilter = filter
    }

    /// Updates the visibility filter (client-side; no API call needed)
    func setVisibilityFilter(_ filter: VisibilityFilter) {
        filterOptions.visibilityFilter = filter
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

    /// Gets unique labels (by lowercased name) from currently displayed issues (excluding label filter)
    var availableLabels: [Label] {
        let issuesInScope = allIssues.filter { filterOptions.matchesExcludingLabels(issue: $0, viewerLogin: viewerLogin) }
        var seen = Set<String>()
        var labels: [Label] = []
        for issue in issuesInScope {
            for label in issue.labels {
                // Hide Kanban state labels from the filter UI.
                if Kanban.isKanbanLabel(label.name) { continue }
                let key = label.name.lowercased()
                if seen.insert(key).inserted {
                    labels.append(Label(id: key, name: key, color: label.color))
                }
            }
        }
        return labels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Toggles label selection (by lowercased name)
    func toggleLabel(_ labelName: String) {
        var options = filterOptions
        let key = labelName.lowercased()
        if options.selectedLabels.contains(key) {
            options.selectedLabels.remove(key)
        } else {
            options.selectedLabels.insert(key)
        }
        filterOptions = options
    }

    /// Clears all label filters
    func clearLabelFilter() {
        var options = filterOptions
        options.selectedLabels.removeAll()
        filterOptions = options
    }
}

/// Summary of a copy/move operation across one or more issues.
struct TransferResult {
    let succeeded: Int
    let failures: [(issue: Issue, message: String)]

    var total: Int { succeeded + failures.count }
}
