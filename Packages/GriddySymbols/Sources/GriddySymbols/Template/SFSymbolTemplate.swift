//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// A parsed SF Symbols template.
public struct SFSymbolTemplate: Sendable {

    /// The symbol name, taken from the root group's identifier.
    public var name: String

    /// The template generation, as printed in the Notes group.
    public var version: String

    /// Typographic metrics, derived from the guide lines.
    public var metrics: TemplateMetrics

    /// Artwork slots found in the Symbols group, keyed by slot.
    public var variants: [SymbolSlot: SFSymbolVariant]

    /// The document exactly as it arrived.
    ///
    /// Preserved so export can put back anything Griddy does not model, and so
    /// the original is always available for comparison. See spec 14.1.
    public var source: Data

    /// Which shape of template this is.
    public var kind: Kind

    public enum Kind: String, Sendable {

        /// Three authored masters for a custom symbol, all at one scale. This
        /// is what the SF Symbols app exports for editing.
        case authoring

        /// All 27 weight/scale slots populated. This is what a static export
        /// of an existing symbol looks like.
        case populated
    }
}

/// One artwork slot within a template.
public struct SFSymbolVariant: Hashable, Sendable {

    public var slot: SymbolSlot

    /// The identifier as written in the file, such as `Regular-S`.
    public var elementID: String

    /// The path's `d` attribute, verbatim.
    public var pathData: String

    /// The parsed commands, for rendering and structural comparison.
    public var commands: [SVGPathCommand]

    /// Subpath count and command count, used to compare topology between
    /// slots. Apple's own templates keep these identical across every slot.
    public var subpathCount: Int {
        commands.reduce(0) { total, command in
            if case .move = command { return total + 1 }
            return total
        }
    }

    public var commandCount: Int {
        commands.count
    }
}
