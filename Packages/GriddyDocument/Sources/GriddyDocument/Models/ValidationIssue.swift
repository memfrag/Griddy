//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// A single validation finding.
///
/// These types live in the document layer rather than in `GriddyValidation`
/// because validation results are persisted document state. The *engine* that
/// produces them lives in `GriddyValidation` and depends on this module, which
/// keeps the dependency direction one-way. See spec 16.2.
public struct ValidationIssue: Codable, Hashable, Sendable, Identifiable {

    public var id: UUID
    public var severity: ValidationSeverity
    public var category: ValidationCategory
    public var message: String
    public var affectedPrimitiveIDs: [PrimitiveID]
    public var affectedMasterIDs: [UUID]
    public var suggestedFix: String?

    public init(id: UUID = UUID(),
                severity: ValidationSeverity,
                category: ValidationCategory,
                message: String,
                affectedPrimitiveIDs: [PrimitiveID] = [],
                affectedMasterIDs: [UUID] = [],
                suggestedFix: String? = nil) {
        self.id = id
        self.severity = severity
        self.category = category
        self.message = message
        self.affectedPrimitiveIDs = affectedPrimitiveIDs
        self.affectedMasterIDs = affectedMasterIDs
        self.suggestedFix = suggestedFix
    }
}

public enum ValidationSeverity: String, Codable, Sendable, CaseIterable {
    case info
    case warning
    case error

    /// Whether an issue at this severity blocks a normal export. See spec 8.7.
    public var blocksExport: Bool {
        self == .error
    }
}

public enum ValidationCategory: String, Codable, Sendable, CaseIterable {
    case template
    case geometry
    case constraint
    case construction
    case visual
    case export
}

/// The validation tier a check belongs to.
///
/// Tiering by cost is what lets validation stay continuous without stalling
/// the canvas. See spec 15.3.
public enum ValidationTier: String, Codable, Sendable, CaseIterable {

    /// Synchronous, every edit, target under 1 ms.
    case structural

    /// Debounced and run off the main actor.
    case geometric

    /// Export only. Includes the full 27-slot solve.
    case full
}

public struct ValidationState: Codable, Hashable, Sendable {

    public var issues: [ValidationIssue]
    public var lastValidatedAt: Date?

    /// Whether the geometric tier is currently recomputing.
    ///
    /// The bottom strip keeps showing the previous result while this is true,
    /// dimmed, rather than blanking. See spec 8.7.
    public var isRecomputing: Bool

    public static let empty = ValidationState(issues: [],
                                              lastValidatedAt: nil,
                                              isRecomputing: false)

    public init(issues: [ValidationIssue],
                lastValidatedAt: Date?,
                isRecomputing: Bool = false) {
        self.issues = issues
        self.lastValidatedAt = lastValidatedAt
        self.isRecomputing = isRecomputing
    }

    public var blocksExport: Bool {
        issues.contains { $0.severity.blocksExport }
    }

    public func issues(at severity: ValidationSeverity) -> [ValidationIssue] {
        issues.filter { $0.severity == severity }
    }
}
