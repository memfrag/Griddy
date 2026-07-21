//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation

/// Forward migration of older document packages.
///
/// The policy is asymmetric by design: older documents migrate forward through
/// ordered steps, newer documents are refused outright. See spec 13.3.
public enum DocumentMigration {

    /// One ordered migration step, taking a package from `fromVersion` to
    /// `fromVersion + 1`.
    struct Step: Sendable {
        let fromVersion: Int
        let apply: @Sendable (SymbolDocumentPackage) -> SymbolDocumentPackage
    }

    /// The registered steps, in ascending order.
    ///
    /// Empty at format version 1: there is nothing older to migrate from yet.
    /// The machinery exists so that adding version 2 is a matter of appending a
    /// step rather than retrofitting a mechanism.
    static let steps: [Step] = []

    /// Throws if the version cannot be handled by this build.
    public static func checkVersion(_ version: Int) throws {
        if version > DocumentFormatVersion.current {
            throw DocumentPackageError.createdByNewerVersion(
                found: version,
                supported: DocumentFormatVersion.current
            )
        }
        if version < DocumentFormatVersion.oldestSupported {
            throw DocumentPackageError.unsupportedLegacyVersion(
                found: version,
                oldestSupported: DocumentFormatVersion.oldestSupported
            )
        }
    }

    /// Applies every step needed to bring a package to the current version.
    ///
    /// The caller is expected to have already validated the version with
    /// ``checkVersion(_:)``.
    static func migrate(_ package: SymbolDocumentPackage) -> SymbolDocumentPackage {
        var package = package
        var version = package.document.metadata.documentFormatVersion

        while version < DocumentFormatVersion.current {
            guard let step = steps.first(where: { $0.fromVersion == version }) else {
                // No step for this version. Stop rather than loop forever; the
                // document keeps its recorded version and is written at the
                // current version on next save.
                break
            }
            package = step.apply(package)
            version += 1
        }

        package.document.metadata.documentFormatVersion = version
        return package
    }

    /// Whether a package needs migrating before it is current.
    public static func needsMigration(_ package: SymbolDocumentPackage) -> Bool {
        package.document.metadata.documentFormatVersion < DocumentFormatVersion.current
    }
}
