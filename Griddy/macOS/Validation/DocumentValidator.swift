//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import Observation
import GriddyDocument
import GriddyValidation

/// Runs validation for one document window, on the schedule spec 15.3 lays out.
///
/// Tier 1 is synchronous on every edit and cheap enough not to be noticed.
/// Tier 2 outlines and reconciles every master, so it is debounced and run off
/// the main actor; while it runs, the previous result stays on screen marked
/// stale rather than blanking. A strip that empties on every keystroke is
/// harder to read than one that lags.
@Observable
@MainActor
final class DocumentValidator {

    private(set) var state: ValidationState = .empty

    /// How long editing must pause before the geometric tier runs.
    private static let debounce = Duration.milliseconds(250)

    private var pending: Task<Void, Never>?

    /// The edit this validator last saw, so a result arriving late can be
    /// discarded rather than overwriting a newer one.
    private var revision = 0

    // No deinit cancelling `pending`: deinit is nonisolated and cannot touch
    // main-actor state. The task holds only a weak self and checks
    // cancellation, so an orphaned one does a little arithmetic and discards
    // the result.

    /// Called on every document change.
    func documentDidChange(to document: SymbolDocument) {
        revision += 1
        let revision = revision

        // Tier 1 lands immediately, replacing only its own findings so the
        // geometric results from the previous pass survive until refreshed.
        let structural = StructuralValidator.issues(in: document)
        state = ValidationState(issues: structural + geometricIssues,
                                lastValidatedAt: Date(),
                                isRecomputing: true)

        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else {
                return
            }

            // Off the main actor: this outlines, resolves booleans and
            // reconciles three masters.
            let geometric = await Task.detached(priority: .utility) {
                GeometricValidator.issues(in: document)
            }.value

            guard !Task.isCancelled else {
                return
            }
            self?.apply(geometric: geometric, structural: structural,
                        revision: revision)
        }
    }

    private var geometricIssues: [ValidationIssue] = []

    private func apply(geometric: [ValidationIssue],
                       structural: [ValidationIssue],
                       revision: Int) {
        // A slower pass from an older edit must not overwrite a newer result.
        guard revision == self.revision else {
            return
        }
        geometricIssues = geometric
        state = ValidationState(issues: structural + geometric,
                                lastValidatedAt: Date(),
                                isRecomputing: false)
    }
}
