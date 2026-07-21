//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// The document format version this build reads and writes.
///
/// Version handling is deliberately asymmetric: older documents migrate
/// forward, newer documents are refused rather than partially read. See
/// spec 13.3.
public enum DocumentFormatVersion {

    /// The version written by this build.
    public static let current: Int = 1

    /// The oldest version this build can migrate from.
    public static let oldestSupported: Int = 1
}

public struct SymbolMetadata: Codable, Hashable, Sendable {

    public var name: String
    public var bundleIdentifierHint: String?
    public var author: String?
    public var createdAt: Date
    public var modifiedAt: Date
    public var appVersion: String
    public var documentFormatVersion: Int
    public var designIntent: SymbolDesignIntent

    public init(name: String,
                bundleIdentifierHint: String? = nil,
                author: String? = nil,
                createdAt: Date,
                modifiedAt: Date,
                appVersion: String,
                documentFormatVersion: Int = DocumentFormatVersion.current,
                designIntent: SymbolDesignIntent = .irregular) {
        self.name = name
        self.bundleIdentifierHint = bundleIdentifierHint
        self.author = author
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.appVersion = appVersion
        self.documentFormatVersion = documentFormatVersion
        self.designIntent = designIntent
    }
}

/// The visual family a symbol is aiming for.
///
/// The canvas emphasises the matching key shape and compares artwork occupancy
/// against it. See spec 9.4.
public enum SymbolDesignIntent: String, Codable, Sendable, CaseIterable {
    case circular
    case square
    case wide
    case tall
    case irregular
}
