//
//  ProgressFooterView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

/// A thin status bar shown at the bottom of the main window while the background task queue is
/// processing GitHub mutations (kanban drags, batch operations, cross-repo copy/move). Renders
/// nothing when the queue is idle.
struct ProgressFooterView: View {
    @ObservedObject var queue: BackgroundTaskQueue

    var body: some View {
        if queue.isProcessing {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    ProgressView(value: Double(queue.currentIndex), total: Double(max(queue.total, 1)))
                        .frame(width: 120)

                    Text(statusText)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(.bar)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var statusText: String {
        let title = queue.currentTitle
        if title.isEmpty {
            return "Processing issue \(queue.currentIndex) of \(queue.total)…"
        }
        return "Processing issue \(queue.currentIndex) of \(queue.total) (\(title))…"
    }
}
