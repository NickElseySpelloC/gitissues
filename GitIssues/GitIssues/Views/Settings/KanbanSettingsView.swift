//
//  KanbanSettingsView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

/// Settings tab for configuring Kanban board states (columns).
///
/// Invariants enforced here so the board and label logic can rely on them:
/// - between `minStates` and `maxStates` states,
/// - exactly one Closed state,
/// - the first state is always Open (it is the default for open issues).
struct KanbanSettingsView: View {
    @StateObject private var kanbanSettings = KanbanSettingsService.shared

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kanban States")
                        .font(.headline)
                    Text("Define the columns for the Kanban board. The first state is the default for open issues; the Closed state is used for closed issues. Drag issues between columns on the board to move them.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    ForEach(Array(kanbanSettings.states.enumerated()), id: \.element.id) { index, state in
                        stateRow(index: index, state: state)
                    }
                }

                HStack {
                    Button {
                        addState()
                    } label: {
                        SwiftUI.Label("Add State", systemImage: "plus")
                    }
                    .disabled(kanbanSettings.states.count >= KanbanSettingsService.maxStates)

                    Spacer()

                    Text("\(kanbanSettings.states.count) of \(KanbanSettingsService.maxStates) states")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Renaming a state does not relabel existing issues; they move to their column the next time you drag them.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func stateRow(index: Int, state: KanbanState) -> some View {
        HStack(spacing: 8) {
            // Reorder controls
            VStack(spacing: 2) {
                Button {
                    move(from: index, to: index - 1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canMove(from: index, to: index - 1))

                Button {
                    move(from: index, to: index + 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canMove(from: index, to: index + 1))
            }
            .font(.caption)

            // Name (label hidden — on macOS the TextField title renders as a leading label)
            TextField("State name", text: nameBinding(for: state))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity)

            // Fixed-width "Default" slot so the trailing columns align across rows.
            Text(index == 0 ? "Default" : "")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .leading)

            // Closed toggle (single-select; first row is always open)
            Toggle("Closed", isOn: Binding(
                get: { state.isClosed },
                set: { newValue in if newValue { setClosed(id: state.id) } }
            ))
            .toggleStyle(.checkbox)
            .disabled(index == 0 || state.isClosed)
            .help(index == 0 ? "The first state is always Open" : "Mark this as the closed state")
            .frame(width: 72, alignment: .leading)

            // Delete
            Button(role: .destructive) {
                deleteState(id: state.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(kanbanSettings.states.count <= KanbanSettingsService.minStates)
        }
    }

    // MARK: - Mutations

    private func nameBinding(for state: KanbanState) -> Binding<String> {
        Binding(
            get: { kanbanSettings.states.first(where: { $0.id == state.id })?.name ?? "" },
            set: { newValue in
                guard let idx = kanbanSettings.states.firstIndex(where: { $0.id == state.id }) else { return }
                kanbanSettings.states[idx].name = newValue
            }
        )
    }

    private func addState() {
        guard kanbanSettings.states.count < KanbanSettingsService.maxStates else { return }
        kanbanSettings.states.append(KanbanState(name: "New State", isClosed: false))
    }

    private func deleteState(id: UUID) {
        guard kanbanSettings.states.count > KanbanSettingsService.minStates,
              let idx = kanbanSettings.states.firstIndex(where: { $0.id == id }) else { return }
        kanbanSettings.states.remove(at: idx)
        normalize()
    }

    private func setClosed(id: UUID) {
        for i in kanbanSettings.states.indices {
            kanbanSettings.states[i].isClosed = (kanbanSettings.states[i].id == id)
        }
    }

    private func canMove(from: Int, to: Int) -> Bool {
        let states = kanbanSettings.states
        guard to >= 0, to < states.count, from != to else { return false }
        // Don't allow the closed state to land in slot 0 (the first state must be open).
        var reordered = states
        let moving = reordered.remove(at: from)
        reordered.insert(moving, at: to)
        return !(reordered.first?.isClosed ?? false)
    }

    private func move(from: Int, to: Int) {
        guard canMove(from: from, to: to) else { return }
        let moving = kanbanSettings.states.remove(at: from)
        kanbanSettings.states.insert(moving, at: to)
    }

    /// Restores the invariants after a delete: exactly one closed state, and the first state open.
    private func normalize() {
        guard !kanbanSettings.states.isEmpty else {
            kanbanSettings.states = KanbanSettingsService.defaultStates
            return
        }
        // Ensure at least one closed state exists.
        if !kanbanSettings.states.contains(where: { $0.isClosed }) {
            kanbanSettings.states[kanbanSettings.states.count - 1].isClosed = true
        }
        // The first state must be open.
        if kanbanSettings.states[0].isClosed {
            kanbanSettings.states[0].isClosed = false
            if !kanbanSettings.states.contains(where: { $0.isClosed }) {
                kanbanSettings.states[kanbanSettings.states.count - 1].isClosed = true
            }
        }
        // Exactly one closed state (keep the first closed found).
        if let firstClosed = kanbanSettings.states.firstIndex(where: { $0.isClosed }) {
            for i in kanbanSettings.states.indices where i != firstClosed {
                kanbanSettings.states[i].isClosed = false
            }
        }
    }
}

#Preview {
    KanbanSettingsView()
}
