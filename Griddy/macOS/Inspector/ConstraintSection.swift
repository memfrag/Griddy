//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyConstraints
import GriddyDocument

/// The relationships declared on the selected primitive.
///
/// Constraints are shown as plain statements rather than as editable fields,
/// because there is nothing to tune: a constraint either holds or is not there.
/// See spec 11.3.
struct ConstraintSection: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    @Environment(\.undoManager) private var undoManager

    let primitive: IconPrimitive

    /// The refusal to show when a constraint cannot be added.
    @State private var rejection: String?

    private var document: SymbolDocument {
        file.document
    }

    private var constraints: [Constraint] {
        document.constraints(for: primitive.id)
    }

    var body: some View {
        Section("Relationships") {
            if constraints.isEmpty {
                Text("No relationships")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(constraints) { constraint in
                    row(for: constraint)
                }
            }

            addMenu

            if let rejection {
                Label(rejection, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(for constraint: Constraint) -> some View {
        HStack {
            Image(systemName: constraint.isEnabled
                  ? "link"
                  : "link.badge.plus")
                .foregroundStyle(constraint.isEnabled ? .secondary : .tertiary)

            Text(constraint.displayName)
                .foregroundStyle(constraint.isEnabled ? .primary : .secondary)
                .strikethrough(!constraint.isEnabled)

            Spacer()

            Button {
                toggle(constraint)
            } label: {
                Image(systemName: constraint.isEnabled ? "pause.circle" : "play.circle")
            }
            .buttonStyle(.borderless)
            .help(constraint.isEnabled ? "Disable" : "Enable")

            Button {
                remove(constraint)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .font(.callout)
    }

    private var addMenu: some View {
        Menu("Add Relationship") {
            Button("Centered Horizontally") {
                add(.centered(CenteredConstraint(primitiveID: primitive.id,
                                                 axis: .horizontal)))
            }
            Button("Centered Vertically") {
                add(.centered(CenteredConstraint(primitiveID: primitive.id,
                                                 axis: .vertical)))
            }
            Button("Centered") {
                add(.centered(CenteredConstraint(primitiveID: primitive.id,
                                                 axis: .both)))
            }

            Divider()

            Button("On Grid Intersection") {
                add(.onGrid(OnGridConstraint(primitiveID: primitive.id)))
            }

            if !document.keyShapes.all.isEmpty {
                Menu("On Key Shape") {
                    ForEach(document.keyShapes.all) { keyShape in
                        Button(keyShape.name) {
                            add(.onKeyShape(OnKeyShapeConstraint(
                                primitiveID: primitive.id,
                                keyShapeID: keyShape.id,
                                overshoot: 0)))
                        }
                    }
                }
            }

            // Relationships between two primitives need a second one selected,
            // so they are offered only when the selection makes them possible.
            if let partner = otherSelectedPrimitiveID {
                Divider()

                Button("Concentric") {
                    add(.concentric(ConcentricConstraint(
                        primitiveIDs: [partner, primitive.id])))
                }
                Button("Equal Radius") {
                    add(.equalRadius(EqualRadiusConstraint(
                        primitiveIDs: [partner, primitive.id])))
                }
                Button("Parallel") {
                    add(.parallel(ParallelConstraint(
                        primitiveIDs: [partner, primitive.id])))
                }
                Button("Perpendicular") {
                    add(.perpendicular(PerpendicularConstraint(
                        primitiveIDs: [partner, primitive.id])))
                }
                Button("Tangent To") {
                    add(.tangent(TangentConstraint(primitiveID: primitive.id,
                                                   targetPrimitiveID: partner)))
                }

                // The distance seeds from where the two primitives are now, so
                // adding the constraint holds them exactly where they sit
                // rather than jumping them together.
                Button("Fixed Distance") {
                    add(.fixedDistance(FixedDistanceConstraint(
                        primitiveID: primitive.id,
                        targetPrimitiveID: partner,
                        distance: currentDistance(to: partner))))
                }

                if bothAreLines(partner) {
                    Button("Equal Length") {
                        add(.equalLength(EqualLengthConstraint(
                            primitiveIDs: [partner, primitive.id])))
                    }
                }
            }

            // Equal spacing needs three or more, distributed along an axis.
            if allSelectedIDs.count >= 3 {
                Divider()
                Button("Equal Spacing (Horizontal)") {
                    add(.equalSpacing(EqualSpacingConstraint(
                        primitiveIDs: allSelectedIDs, axis: .horizontal)))
                }
                Button("Equal Spacing (Vertical)") {
                    add(.equalSpacing(EqualSpacingConstraint(
                        primitiveIDs: allSelectedIDs, axis: .vertical)))
                }
            }
        }
        .menuStyle(.borderlessButton)
    }

    /// Every selected primitive, the inspected one first so it reads as the
    /// subject of the relationship.
    private var allSelectedIDs: [PrimitiveID] {
        [primitive.id] + editor.selection.filter { $0 != primitive.id }
    }

    private func currentDistance(to partner: PrimitiveID) -> Double {
        guard let a = primitive.anchor,
              let b = document.primitive(withID: partner)?.anchor else {
            return 1
        }
        return a.distance(to: b)
    }

    private func bothAreLines(_ partner: PrimitiveID) -> Bool {
        if case .line = primitive,
           case .line? = document.primitive(withID: partner) {
            return true
        }
        return false
    }

    /// Another selected primitive to relate this one to, if there is exactly
    /// one.
    private var otherSelectedPrimitiveID: PrimitiveID? {
        let others = editor.selection.filter { $0 != primitive.id }
        return others.count == 1 ? others.first : nil
    }

    // MARK: Actions

    private func add(_ constraint: Constraint) {
        rejection = nil

        // Attempt on a copy so a refusal cannot leave the document half-changed
        // or put an empty entry on the undo stack.
        var trial = document
        do {
            try trial.addConstraint(constraint)
        } catch let error as ConstraintRejected {
            rejection = error.message
            return
        } catch {
            rejection = error.localizedDescription
            return
        }

        // The constraint record and the geometry it moved are one action, so
        // one undo puts everything back. See spec 11.2.
        file.perform("Add \(constraint.displayName)", undoManager: undoManager) {
            $0 = trial
        }
    }

    private func toggle(_ constraint: Constraint) {
        rejection = nil
        let enabling = !constraint.isEnabled
        file.perform(enabling ? "Enable Relationship" : "Disable Relationship",
                     undoManager: undoManager) { document in
            document.setConstraint(constraint.id, enabled: enabling)
            if enabling {
                document.resolveConstraints()
            }
        }
    }

    private func remove(_ constraint: Constraint) {
        rejection = nil
        file.perform("Remove \(constraint.displayName)",
                     undoManager: undoManager) { document in
            document.removeConstraint(withID: constraint.id)
        }
    }
}
