//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// Semantic properties of the selected primitive.
///
/// Deliberately not a generic vector inspector: an arc shows a radius and two
/// angles, not eight Bézier control points. See spec 8.6.
struct PrimitiveInspector: View {

    @ObservedObject var file: SymbolDocumentFile
    @Bindable var editor: CanvasEditor
    @Environment(\.undoManager) private var undoManager

    let primitive: IconPrimitive

    var body: some View {
        Form {
            Section("Geometry") {
                LabeledContent("Shape", value: primitive.kindName)
                geometryFields
            }

            if case .polyline(let polyline) = primitive, polyline.isSmooth {
                PointTensionSection(file: file, editor: editor, polyline: polyline)
            }

            ConstraintSection(file: file, editor: editor, primitive: primitive)

            // Only for a real primitive, not a compound: a compound's shape is
            // its children's, which carry their own adjustments.
            if !isCompound {
                MasterAdjustmentSection(file: file, editor: editor,
                                        primitive: primitive)
            }

            Section("Stroke") {
                LabeledContent("Width") {
                    Text(format(file.document.strokeWidth(for: primitive,
                                                          weight: editor.activeWeight)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                LabeledContent("Width ×") {
                    TextField("Multiplier", value: strokeMultiplierBinding,
                              format: .number.precision(.fractionLength(0...2)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 72)
                }
                // A line has two distinct ends, so it caps them separately;
                // every other kind is closed or symmetric and takes one cap.
                if isLine {
                    capPicker("Start Cap", selection: endCapBinding(\.startCap))
                    capPicker("End Cap", selection: endCapBinding(\.endCap))
                } else {
                    capPicker("Cap", selection: capBinding)
                }
                Picker("Join", selection: joinBinding) {
                    Text("Miter").tag(GriddyGeometry.LineJoin.miter)
                    Text("Round").tag(GriddyGeometry.LineJoin.round)
                    Text("Bevel").tag(GriddyGeometry.LineJoin.bevel)
                }
            }

            Section("Export") {
                Toggle("Visible", isOn: visibleBinding)
                Toggle("Include in export", isOn: exportBinding)
            }
        }
        .formStyle(.grouped)
    }

    private var isCompound: Bool {
        if case .compound = primitive { true } else { false }
    }

    // MARK: Geometry fields

    @ViewBuilder
    private var geometryFields: some View {
        switch primitive {
        case .circle(let circle):
            unitField("Radius", value: radiusBinding(circle))
            unitField("Center X", value: circleCenterBinding(circle, axis: .x))
            unitField("Center Y", value: circleCenterBinding(circle, axis: .y))

        case .arc(let arc):
            unitField("Radius", value: arcRadiusBinding(arc))
            degreeField("Start", value: arcAngleBinding(arc, isStart: true))
            degreeField("End", value: arcAngleBinding(arc, isStart: false))
            Picker("Direction", selection: arcDirectionBinding(arc)) {
                Text("Counterclockwise").tag(false)
                Text("Clockwise").tag(true)
            }

        case .line(let line):
            unitField("Length", value: .constant(line.length))
                .disabled(true)
            LabeledContent("Start", value: describe(line.start))
            LabeledContent("End", value: describe(line.end))

        case .roundedRect(let rect):
            unitField("Corner radius", value: cornerRadiusBinding(rect))
            LabeledContent("Size", value: describe(rect.bounds.size))

        case .capsule(let capsule):
            LabeledContent("Size", value: describe(capsule.bounds.size))
            LabeledContent("Corner radius",
                           value: format(capsule.cornerRadius))

        case .polyline(let polyline):
            LabeledContent("Points", value: "\(polyline.points.count)")

        case .symmetricPath(let path):
            LabeledContent("Points", value: "\(path.points.count)")
            LabeledContent("Axis", value: path.axis.rawValue.capitalized)

        case .compound(let compound):
            LabeledContent("Operation", value: compound.operation.rawValue.capitalized)
            LabeledContent("Children", value: "\(compound.children.count)")

        case .importedPath:
            LabeledContent("Source", value: "Imported path")
            Text("Imported geometry has no semantic properties until it is "
                 + "converted to a primitive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Editing

    /// Wraps a property edit so it becomes one undo step with a semantic name.
    private func edit(_ actionName: String,
                      _ mutate: @escaping (inout IconPrimitive) -> Void) {
        file.perform(actionName, undoManager: undoManager) { document in
            guard var updated = document.primitive(withID: primitive.id) else {
                return
            }
            mutate(&updated)
            document.replacePrimitive(updated)
        }
    }

    private func radiusBinding(_ circle: CirclePrimitive) -> Binding<Double> {
        Binding(
            get: { circle.radius },
            set: { newValue in
                edit("Change Radius") { primitive in
                    guard case .circle(var updated) = primitive else {
                        return
                    }
                    updated.radius = max(0, newValue)
                    primitive = .circle(updated)
                }
            }
        )
    }

    private enum Axis { case x, y }

    private func circleCenterBinding(_ circle: CirclePrimitive,
                                     axis: Axis) -> Binding<Double> {
        Binding(
            get: { axis == .x ? circle.center.x : circle.center.y },
            set: { newValue in
                edit("Move Circle") { primitive in
                    guard case .circle(var updated) = primitive else {
                        return
                    }
                    switch axis {
                    case .x: updated.center.x = newValue
                    case .y: updated.center.y = newValue
                    }
                    primitive = .circle(updated)
                }
            }
        )
    }

    private func arcRadiusBinding(_ arc: ArcPrimitive) -> Binding<Double> {
        Binding(
            get: { arc.radius },
            set: { newValue in
                edit("Change Radius") { primitive in
                    guard case .arc(var updated) = primitive else {
                        return
                    }
                    updated.radius = max(0, newValue)
                    primitive = .arc(updated)
                }
            }
        )
    }

    private func arcAngleBinding(_ arc: ArcPrimitive,
                                 isStart: Bool) -> Binding<Double> {
        Binding(
            get: { isStart ? arc.startAngle.degrees : arc.endAngle.degrees },
            set: { newValue in
                edit(isStart ? "Change Start Angle" : "Change End Angle") { primitive in
                    guard case .arc(var updated) = primitive else {
                        return
                    }
                    if isStart {
                        updated.startAngle = IconAngle(degrees: newValue)
                    } else {
                        updated.endAngle = IconAngle(degrees: newValue)
                    }
                    primitive = .arc(updated)
                }
            }
        )
    }

    private func arcDirectionBinding(_ arc: ArcPrimitive) -> Binding<Bool> {
        Binding(
            get: { arc.isClockwise },
            set: { newValue in
                edit("Change Direction") { primitive in
                    guard case .arc(var updated) = primitive else {
                        return
                    }
                    updated.isClockwise = newValue
                    primitive = .arc(updated)
                }
            }
        )
    }

    private func cornerRadiusBinding(_ rect: RoundedRectPrimitive) -> Binding<Double> {
        Binding(
            get: { rect.cornerRadius },
            set: { newValue in
                edit("Change Corner Radius") { primitive in
                    guard case .roundedRect(var updated) = primitive else {
                        return
                    }
                    updated.cornerRadius = max(0, newValue)
                    primitive = .roundedRect(updated)
                }
            }
        )
    }

    private var isLine: Bool {
        if case .line = primitive { true } else { false }
    }

    private func capPicker(_ label: String,
                           selection: Binding<GriddyGeometry.LineCap>) -> some View {
        Picker(label, selection: selection) {
            Text("Butt").tag(GriddyGeometry.LineCap.butt)
            Text("Round").tag(GriddyGeometry.LineCap.round)
            Text("Square").tag(GriddyGeometry.LineCap.square)
        }
    }

    /// A binding to one end's cap. Reads the resolved cap so an un-overridden
    /// end shows the real value; writing sets that end's override.
    private func endCapBinding(_ keyPath: WritableKeyPath<GriddyGeometry.StrokeStyleDefinition, GriddyGeometry.LineCap?>) -> Binding<GriddyGeometry.LineCap> {
        Binding(
            get: {
                primitive.attributes.stroke[keyPath: keyPath]
                    ?? primitive.attributes.stroke.lineCap
            },
            set: { newValue in
                edit("Change Line Cap") {
                    $0.attributes.stroke[keyPath: keyPath] = newValue
                }
            }
        )
    }

    /// The per-shape stroke multiplier, clamped so it cannot invert the outline.
    private var strokeMultiplierBinding: Binding<Double> {
        Binding(
            get: { primitive.attributes.stroke.widthMultiplier },
            set: { newValue in
                edit("Change Line Width") {
                    $0.attributes.stroke.widthMultiplier = max(0, newValue)
                }
            }
        )
    }

    private var capBinding: Binding<GriddyGeometry.LineCap> {
        Binding(
            get: { primitive.attributes.stroke.lineCap },
            set: { newValue in
                edit("Change Line Cap") { $0.attributes.stroke.lineCap = newValue }
            }
        )
    }

    private var joinBinding: Binding<GriddyGeometry.LineJoin> {
        Binding(
            get: { primitive.attributes.stroke.lineJoin },
            set: { newValue in
                edit("Change Line Join") { $0.attributes.stroke.lineJoin = newValue }
            }
        )
    }

    private var visibleBinding: Binding<Bool> {
        Binding(
            get: { primitive.attributes.isVisible },
            set: { newValue in
                edit(newValue ? "Show Primitive" : "Hide Primitive") {
                    $0.attributes.isVisible = newValue
                }
            }
        )
    }

    private var exportBinding: Binding<Bool> {
        Binding(
            get: { primitive.attributes.participatesInExport },
            set: { newValue in
                edit("Change Export Participation") {
                    $0.attributes.participatesInExport = newValue
                }
            }
        )
    }

    // MARK: Fields

    private func unitField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField(label, value: value, format: .number.precision(.fractionLength(0...3)))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 90)
                    .monospacedDigit()
                Text("u")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private func degreeField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField(label, value: value, format: .number.precision(.fractionLength(0...2)))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 90)
                    .monospacedDigit()
                Text("°")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    // MARK: Formatting

    private func format(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.3g", value)
    }

    private func describe(_ point: IconPoint) -> String {
        "\(format(point.x)), \(format(point.y))"
    }

    private func describe(_ size: IconSize) -> String {
        "\(format(size.width)) × \(format(size.height)) u"
    }
}
