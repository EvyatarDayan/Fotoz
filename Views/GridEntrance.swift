//
//  GridEntrance.swift
//  Fotoz
//

import SwiftUI

enum GridEntrance {
    /// Snappy spring with light overshoot so cells settle quickly.
    static let animation: Animation = .spring(response: 0.34, dampingFraction: 0.9, blendDuration: 0.08)
    /// Start closer to full size for a subtler, smoother enlarge.
    static let startScale: CGFloat = 0.92
    /// Delay between revealing each cell.
    static let staggerNanoseconds: UInt64 = 28_000_000
    static let settleNanoseconds: UInt64 = 160_000_000
}

/// Drives one-by-one enlarge entrance for photo grids (Home + folder).
@MainActor
@Observable
final class GridEntranceController {
    private(set) var visibleIDs: Set<UUID> = []
    private(set) var didFinish = false
    private var task: Task<Void, Never>?

    func isVisible(_ id: UUID) -> Bool {
        didFinish || visibleIDs.contains(id)
    }

    func playIfNeeded(ids: [UUID]) {
        guard !didFinish, task == nil else {
            if didFinish {
                for id in ids where !visibleIDs.contains(id) {
                    visibleIDs.insert(id)
                }
            }
            return
        }

        guard !ids.isEmpty else { return }

        task = Task { @MainActor in
            for id in ids {
                guard !Task.isCancelled else { return }
                visibleIDs.insert(id)
                try? await Task.sleep(nanoseconds: GridEntrance.staggerNanoseconds)
            }
            try? await Task.sleep(nanoseconds: GridEntrance.settleNanoseconds)
            didFinish = true
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
