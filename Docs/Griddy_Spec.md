# Griddy Product and Technical Specification

## 1. Overview

**Griddy** is a focused macOS editor for designing custom SF Symbols using grids, key shapes, constraints, and connected weight masters.

It is not intended to be a general-purpose vector design tool. Griddy should feel like a constrained drafting instrument for icon designers: precise, semantic, and optimized for creating simple line-art symbols that can survive Apple's SF Symbols import workflow.

### One-line Positioning

> Griddy is a parametric icon editor for designing custom SF Symbols on grids, key shapes, and interoperable weight masters.

### Product Descriptor

- **App name:** Griddy
- **Category:** SF Symbol editor
- **Tagline:** Draw icons with structure.
- **Native document extension:** `.griddy`
- **Document package example:** `CameraBadge.griddy`
- **Optional command-line utility:** `griddytool`

## 2. Product Vision

Designing custom SF Symbols requires more than drawing attractive vector paths. A symbol must respect typographic alignment, weights, scales, margins, interpolation rules, and small-size readability. General tools such as Figma, Sketch, and Illustrator allow too much freedom and do not understand the semantic structure of SF Symbols.

Griddy should make the correct symbol-design workflow the default:

- Start from SF Symbols-compatible templates.
- Draw with semantic primitives rather than arbitrary paths.
- Use grids, safe areas, and key shapes as first-class design constraints.
- Generate related weight masters from one underlying construction.
- Validate export readiness continuously.
- Preserve design intent, not only SVG paths.

The core product bet is that Griddy stores and edits the intent behind an icon: two arcs are concentric, a detail is mirrored, a shape overshoots a key shape by a controlled amount, and every weight variant is derived from the same primitive identity.

## 3. Target Users

### Primary Users

- macOS and iOS app designers creating custom SF Symbols.
- Design-system maintainers building symbol families.
- Indie developers who need app-specific icons but do not want a full design suite.
- Engineers producing simple custom symbols for internal or shipping apps.

### Secondary Users

- Icon designers who want a constrained grid-first workflow.
- Teams validating consistency across a symbol set.
- Developers building symbol libraries with automated SVG export checks.

## 4. Goals

1. Provide a focused editor for monochrome SF Symbol-compatible line-art icons.
2. Preserve SF Symbols template structure during import and export.
3. Make grid, key-shape, margin, baseline, and safe-area geometry visible and meaningful.
4. Represent artwork using semantic primitives and relationships.
5. Support connected weight masters so Ultralight, Regular, and Black variants share topology.
6. Allow controlled optical corrections without destroying parametric structure.
7. Continuously validate whether the symbol is likely to import correctly into Apple's SF Symbols app.
8. Provide useful contextual previews at common point sizes, weights, and UI placements.
9. Maintain a native document format that stores construction data, not just SVG.
10. Keep the UI quiet, direct, and professional.

## 5. Non-goals

Griddy should deliberately avoid becoming a broad design tool.

Out of scope for the MVP:

- General page layout.
- Infinite canvases.
- Arbitrary image or bitmap placement.
- Gradients, shadows, filters, and complex visual effects.
- Advanced typography or text editing. There is no text tool. Symbols that contain glyphs must be constructed from primitives or imported as fallback paths.
- Full-color illustration tooling.
- Plugin-based rendering effects.
- Collaborative multiplayer editing.
- Full SF Symbols library management.
- Animation annotations.
- Complete support for every SF Symbols rendering mode.
- A general Bézier editor as the primary drawing experience.

The MVP may include an advanced node-editing escape hatch later, but the default workflow must remain semantic and constrained.

Note that boolean geometry is explicitly **in** scope. Griddy implements a real curve-curve boolean solver (§10.5). This is not a general vector-editing feature; it is required infrastructure for turning stroked construction geometry into the filled outlines SF Symbols requires.

## 6. Design Principles

### 6.1 Store Intent, Not Just Paths

SVG paths are an export artifact. Griddy documents should store primitives, constraints, relationships, variant adjustments, and validation metadata.

### 6.2 Constraint-first Drawing

The editor should make it natural to say:

- This circle is centered on the canvas.
- This arc is tangent to that circle.
- These two details are mirrored.
- This endpoint sits on a grid intersection.
- This shape overshoots the circular key shape by 0.25 units.

### 6.3 Restrictive by Default

The app should prevent or warn against choices that are likely to produce invalid or poor SF Symbols. Restriction is a product feature.

### 6.4 Optical Corrections Are Valid

The grid is guidance, not a prison. Designers must be able to apply small optical offsets, overshoots, and compensations. These should be explicit properties rather than accidental path edits.

### 6.5 Continuous Feedback

Validation, small-size previews, interpolation checks, and visual-balance warnings should be visible while designing, not only at export time. This principle is why Griddy has no editing modes (§8.4): hiding feedback behind a mode switch contradicts it.

## 7. Core User Workflows

### 7.1 Create a New Symbol

1. User chooses **New Symbol**.
2. User selects a template source:
   - Blank SF Symbol-compatible template.
   - Imported SF Symbols SVG template.
   - Existing system symbol used as reference.
   - Grid/key-shape preset.
3. User names the symbol.
4. Griddy creates a `.griddy` document package.
5. The canvas opens with the Regular master active.

**New Symbol and Import Template are the same code path.** A new document is created by loading the bundled `Resources/BlankSymbolTemplate.svg` through the ordinary template importer (§14.2). There is no separate "blank document" construction path, and consequently no case in which a document lacks a template-derived coordinate system (§9.1).

### 7.2 Import an SF Symbols Template

1. User imports an SVG exported from Apple's SF Symbols app.
2. Griddy parses the template structure.
3. The app extracts:
   - Symbol canvas bounds.
   - Alignment rects.
   - Margins.
   - Baseline and typographic guides.
   - Weight and scale groups, where available.
   - Existing paths as imported fallback geometry.
4. Griddy validates the template hierarchy and version (§14.1).
5. Griddy stores the original template as `source-template.svg`.

### 7.3 Draw an Icon

1. User chooses a semantic drawing tool:
   - Line
   - Arc
   - Circle
   - Rounded rectangle
   - Capsule
   - Polyline
   - Symmetric path
   - Mirrored component
   - Cutout
2. The canvas snaps to grid, guide, and key-shape relationships.
3. The inspector shows editable semantic properties.
4. The validation panel updates continuously.

### 7.4 Create Weight Masters

1. User draws the canonical Regular master.
2. Griddy derives Ultralight and Black masters from the same primitives.
3. User adjusts per-master parameters:
   - Stroke width.
   - Interior compensation.
   - Optical offsets.
   - Corner-radius compensation.
   - Detail suppression warnings.
4. Griddy checks whether the construction remains coherent across masters.

### 7.5 Preview the Symbol

User sees previews:

- 12 pt, 14 pt, 17 pt, 20 pt, 24 pt, and 32 pt.
- Light and dark backgrounds.
- Multiple weights.
- In toolbar context.
- In sidebar-row context.
- Inline with San Francisco-like text.
- Beside comparable system SF Symbols (§8.3).

### 7.6 Export to SF Symbols

1. User chooses **Export SF Symbols SVG**.
2. Griddy runs validation.
3. Blocking errors must be fixed or explicitly bypassed if safe.
4. Griddy generates an SVG preserving required SF Symbols structure, with the three authored masters written into the template's three slots and reconciled so they interpolate (§14.5).
5. User imports the SVG into Apple's SF Symbols app as the final authority.

## 8. UX Specification

### 8.1 Application Layout

Use a native macOS three-column document window:

- **Left sidebar:** document structure.
- **Center:** drawing canvas.
- **Right inspector:** semantic properties.
- **Bottom strip:** validation status and small-size previews.

All four regions are visible and live simultaneously. See §8.4.

### 8.2 Left Sidebar

Suggested hierarchy:

```text
Symbol
  Construction
    Grid
    Key Shapes
    Safe Area
    Margins
    Baseline
  Layers
    Outer Body
    Detail
    Badge
  Masters
    Ultralight
    Regular
    Black
  Preview Set
  Export
```

Expected interactions:

- Select layer or primitive.
- Toggle visibility of construction guides.
- Switch active master.
- Reorder layers where semantically safe.
- See validation badges for layers and masters.

### 8.3 Center Canvas

The canvas has three conceptual layers:

#### Construction Layer

- Primary grid.
- Secondary grid.
- Safe area.
- Margins.
- Baseline.
- Alignment guides.
- Key shapes.
- Symmetry axes.
- Measurements.

#### Artwork Layer

- Semantic primitives.
- Stroke centerlines.
- Filled previews.
- Compound shapes.
- Boolean construction results.
- Selected primitive handles.

#### Evaluation Layer

- Optical bounding box.
- Visual center marker.
- Negative-space warnings.
- Blur preview.
- Small-size raster overlay.
- System-symbol comparison.

**System-symbol comparison.** Comparison is against real system SF Symbols obtained through `NSImage(systemSymbolName:accessibilityDescription:)` configured to the active weight, scale, and point size. Griddy does not reference or read other `.griddy` documents (§13.1). System symbols are both easier to obtain and the more useful reference, since they define the visual weight a custom symbol must sit alongside.

### 8.4 No Modes

Griddy has no editing modes and no global mode state.

Earlier drafts of this specification proposed five modes (Construct, Adjust, Compare, Annotate, Preview). That model is withdrawn. It conflicts with §6.5: a mode switch hides feedback that the principle requires to be continuously visible, and it forces every view to react to a global enum for no user benefit.

The activities the modes described are covered by the persistent layout instead:

| Former mode | Covered by |
|---|---|
| Construct | The active toolbar tool |
| Adjust | The active toolbar tool, plus the inspector |
| Compare | The bottom strip's preview section, and the evaluation layer |
| Annotate | The inspector's Export tab and the validation section |
| Preview | The bottom strip's preview section |

Consequently there is no mode-switcher control, and no mode controller layer in the architecture.

### 8.5 Toolbar

Primary controls, matching `Docs/Griddy_Mockup.png`:

- Selection tool.
- Circle tool.
- Rounded rectangle tool.
- Polyline / path tool.
- Line tool.
- Arc tool.
- Capsule tool.
- Symmetry tool.
- Hand (pan) tool.
- Zoom tool.
- Undo and redo.
- Zoom level control.
- Grid visibility toggle.
- Key-shape and alignment guide toggles.
- Sidebar and inspector panel toggles.
- Export button.

There is no mode switcher (§8.4) and no text tool (§5).

Boolean union and subtract are **not** toolbar tools. They are properties of a `CompoundPrimitive` (§10.4) created from the current selection via a menu command, so that the operation remains an editable document relationship rather than a destructive canvas action.

### 8.6 Right Inspector

The inspector should avoid generic vector fields where possible. It should expose semantic properties.

The inspector is organized into four tabs:

| Tab | Contents |
|---|---|
| Geometry | Shape kind and its semantic parameters, optical correction |
| Constraints | Declared relationships on the selection, add/remove |
| Master | Per-master adjustments for the active master |
| Export | Layer role, rendering role, export participation, per-item validation |

Example for an arc, in the Geometry tab:

```text
Geometry
  Shape: Arc
  Center: Canvas center
  Radius: 6 units
  Start angle: 15 deg
  End angle: 165 deg

Relationships
  Centered horizontally
  Tangent to outer circle
  Mirrored across vertical axis

Stroke
  Width: System Regular
  Cap: Round
  Join: Round

Optical Correction
  Vertical offset: -0.125 units
  Overshoot: 0.25 units
```

The `SwiftUIToolbox` package (already a project dependency) provides `InspectorGrid`, `InspectorLabel`, `InspectorTextValue`, `InspectorDivider`, and `InspectorSectionHeader`. The inspector should be assembled from these rather than hand-rolled, so label alignment and spacing stay consistent.

### 8.7 Bottom Validation and Preview Strip

The bottom strip should show:

```text
OK Template structure preserved
OK Paths resolve in every exported slot
OK Artwork inside permitted bounds
OK Margins present
Warning Visual center is 0.32 units left of canvas center
Warning Detail may close at 12 pt / Black
```

Use severity levels:

- **OK:** no issue.
- **Info:** notable but not harmful.
- **Warning:** likely design or export concern.
- **Error:** must be fixed before normal export.

Because validation is tiered and partly asynchronous (§15.3), the strip must distinguish *current* from *stale* results. Stale results remain visible, dimmed, with a subtle progress affordance. The strip must never blank out or block while recomputing.

## 9. Grid and Key-shape System

### 9.1 Coordinate System

The document defines a normalized icon coordinate system independent from screen pixels. **The coordinate system is derived entirely from the template**, never authored directly and never hardcoded.

On import (including the blank template used for new documents, §7.1), Griddy extracts the baseline and capline guides from the template and derives:

```text
1 unit (1u) = (capline.y - baseline.y) / 16
```

From that single anchor:

- **Canvas height** is fixed at 16u, spanning baseline to capline.
- **Canvas width** is free. It defaults to 16u but grows for wide symbols, because SF Symbols are deliberately not square.
- **Origin** is at the intersection of the baseline and the template's left margin.
- **Y increases upward** in Griddy coordinates. SVG's Y-down convention is applied at export.
- **Safe area, margins, and alignment rects** are read from the template and expressed in units.

Anchoring the unit to cap height rather than to the alignment rect means the grid lines up with the typographic guides designers actually align to, and the vertical module stays stable across templates.

The export transform into SF Symbols SVG coordinates is therefore a uniform scale, a Y flip, and a translation to the target slot's origin. No non-uniform scaling or shear is ever applied.

### 9.2 Grid Definition

```swift
struct GridDefinition: Codable, Equatable {
    var canvasSize: CGSizeCodable
    var safeArea: RectCodable
    var primaryInterval: Double
    var secondaryDivisions: Int
    var showsPrimaryGrid: Bool
    var showsSecondaryGrid: Bool
    var snapTolerance: Double
}
```

`canvasSize` and `safeArea` are **populated from the template** (§9.1) and are not user-authored. The remaining fields are user-configurable, with these defaults:

```text
primaryInterval    1.0u        (16 rows between baseline and capline)
secondaryDivisions 4           (0.25u snap increments)
snapTolerance      0.125u
```

### 9.3 Key Shapes

Key shapes are configurable construction guides used to harmonize visual size across icons.

Recommended default key shapes:

- Circle.
- Square.
- Horizontal rectangle.
- Vertical rectangle.
- Optional custom key shapes.

```swift
struct KeyShapeSet: Codable, Equatable {
    var circle: KeyShape
    var square: KeyShape
    var horizontalRectangle: KeyShape
    var verticalRectangle: KeyShape
    var customShapes: [KeyShape]
}

struct KeyShape: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var kind: KeyShapeKind
    var bounds: RectCodable
    var opticalOvershoot: Double
    var recommendedAttachmentPoints: [PointCodable]
    var maximumExtent: RectCodable?
    var warningPolicy: KeyShapeWarningPolicy
}

enum KeyShapeKind: String, Codable {
    case circle
    case square
    case horizontalRectangle
    case verticalRectangle
    case customPath
}
```

### 9.4 Design Intent

Each symbol may declare an intended visual family:

```swift
enum SymbolDesignIntent: String, Codable {
    case circular
    case square
    case wide
    case tall
    case irregular
}
```

The canvas should emphasize the corresponding key shape and compare artwork occupancy against it.

## 10. Geometry Model

### 10.1 Primitive-based Drawing

Griddy should model artwork as semantic primitives:

```swift
enum IconPrimitive: Codable, Identifiable, Equatable {
    case line(LinePrimitive)
    case arc(ArcPrimitive)
    case circle(CirclePrimitive)
    case roundedRect(RoundedRectPrimitive)
    case capsule(CapsulePrimitive)
    case polyline(PolylinePrimitive)
    case symmetricPath(SymmetricPathPrimitive)
    case compound(CompoundPrimitive)
    case importedPath(ImportedPathPrimitive)
}
```

Each primitive should have:

- Stable identity.
- Layer membership.
- Visibility.
- Stroke style.
- Fill style where applicable.
- Constraint references.
- Per-master adjustments.
- Export participation.

`ImportedPathPrimitive` is the fallback record for geometry that arrived from an SVG and has not been converted to a semantic primitive (§14.3). It carries raw path data and renders and exports faithfully, but exposes no semantic properties.

### 10.2 Primitive Identity Across Masters

A primitive must keep the same identity across every weight master. Weight-specific differences should be represented as adjustments, not separate unrelated paths.

```swift
struct PrimitiveID: Codable, Hashable, Equatable {
    var rawValue: UUID
}

struct MasterAdjustment: Codable, Equatable {
    var primitiveID: PrimitiveID
    var strokeWidthDelta: Double
    var positionOffset: VectorCodable
    var radiusDelta: Double
    var cornerRadiusDelta: Double
    var opticalCompensation: OpticalCompensation
}
```

### 10.3 Stroke and Appearance

```swift
struct StrokeStyleDefinition: Codable, Equatable {
    var width: StrokeWidthSource
    var lineCap: LineCap
    var lineJoin: LineJoin
    var miterLimit: Double
}

enum StrokeWidthSource: Codable, Equatable {
    case systemWeight
    case fixed(Double)
    case derived(base: Double, scaleFactor: Double)
}

enum LineCap: String, Codable {
    case butt
    case round
    case square
}

enum LineJoin: String, Codable {
    case miter
    case round
    case bevel
}
```

Stroke width, cap, and join describe the *construction* stroke. They are not exported as SVG stroke attributes; they are inputs to outlining (§10.5).

### 10.4 Boolean Operations

Boolean operations should be modeled explicitly:

```swift
struct CompoundPrimitive: Codable, Identifiable, Equatable {
    var id: PrimitiveID
    var operation: CompoundOperation
    var children: [PrimitiveID]
}

enum CompoundOperation: String, Codable {
    case union
    case subtract
    case intersect
}
```

The resolved path may be cached, but the source primitives must remain editable.

### 10.5 Outlining and Boolean Resolution

This section describes the single most important piece of geometry in Griddy, and the one with the least margin for error.

**The problem.** Griddy authors artwork as stroked centerlines. SF Symbols templates contain *filled* paths and carry no stroke attributes. Every exported path must therefore be a closed, filled outline. Converting a stroked centerline into a filled outline is not a formatting step; it is a real geometric construction, and it must happen before anything is written to SVG.

**Outlining is analytic, never flattened.** Griddy does not use `CGPath.copy(strokingWithWidth:)`. That API flattens curves into large numbers of short line segments, producing paths that are enormous, unreadable, and unstable. Instead each primitive has a closed-form outline:

| Primitive | Outline construction |
|---|---|
| Line | Rounded rectangle: two parallel segments joined by cap geometry |
| Circle | Annulus: two concentric circles, inner reverse-wound |
| Arc | Outer arc, end cap, inner arc reversed, start cap |
| Rounded rect | Two nested rounded rectangles, inner reverse-wound |
| Capsule | Two nested capsules, inner reverse-wound |
| Polyline | Offset chain with join geometry at each vertex, caps at each end |
| Symmetric path | Outline the source half, then mirror across the axis |

Outlines are expressed in exact arcs and Béziers. Curve fidelity is preserved all the way to the SVG writer, which is what keeps exported paths small and legible.

**Boolean resolution follows outlining.** Overlapping outlines are combined by a real curve-curve boolean solver, producing minimal, non-overlapping outlines that match what a designer would hand-author. The solver:

1. Computes curve-curve intersections between outline segments.
2. Splits segments at intersection parameters.
3. Classifies resulting segments as inside or outside the other operand.
4. Stitches surviving segments into closed contours.
5. Assigns winding direction so nested contours read as holes.

Union, subtract, and intersect are all supported (§10.4).

**Ordering is fixed and must not be reversed:** resolve constraints, then apply per-master adjustments, then outline, then boolean-resolve. Outlining a boolean result, or booleaning centerlines, produces incorrect geometry.

**Consequence for interpolation.** Boolean results are weight-dependent: the number and position of intersections between two outlines changes as stroke width changes, so two masters of the same symbol can legitimately have different path structure. Because export must supply three masters that interpolate (§12.2), that difference has to be reconciled — by a compatibility pass applied to the finished paths (§12.6), not by constraining the solver. The solver stays free; reconciliation happens once, at the end, where it can be checked.

## 11. Constraint System

### 11.1 Constraint Types

Supported constraints:

- On grid intersection.
- On key-shape boundary.
- Centered horizontally.
- Centered vertically.
- Equal spacing.
- Equal radius.
- Equal length.
- Tangent.
- Concentric.
- Symmetric.
- Parallel.
- Perpendicular.
- Fixed angle.
- Fixed distance.
- Optical offset.

```swift
enum Constraint: Codable, Identifiable, Equatable {
    case onGrid(OnGridConstraint)
    case onKeyShape(OnKeyShapeConstraint)
    case centered(CenteredConstraint)
    case equalSpacing(EqualSpacingConstraint)
    case equalRadius(EqualRadiusConstraint)
    case equalLength(EqualLengthConstraint)
    case tangent(TangentConstraint)
    case concentric(ConcentricConstraint)
    case symmetric(SymmetricConstraint)
    case parallel(ParallelConstraint)
    case perpendicular(PerpendicularConstraint)
    case fixedAngle(FixedAngleConstraint)
    case fixedDistance(FixedDistanceConstraint)
    case opticalOffset(OpticalOffsetConstraint)
}
```

### 11.2 Constraints Are Invariants

Griddy does not implement a CAD-grade solver, and it does not need one, because constraints are treated as **invariants that cannot be violated** rather than goals to be re-satisfied after the fact.

**During a drag, constraints restrict available degrees of freedom.** A horizontally-centered circle can only be dragged vertically. A tangent arc slides along its tangency. The constraint is applied to the *input* of the edit, not checked afterwards:

```text
circle: centeredHorizontally
drag by (dx, dy)
  -> apply (0, dy)
```

The canvas reflects the restriction in the cursor and drag affordance, so the limitation is legible rather than mysterious. To move geometry outside a constraint, the user disables or removes the constraint first.

**Adding a constraint snaps geometry into compliance.** Adding a constraint to geometry that does not currently satisfy it moves the geometry immediately. The movement and the constraint record are a single undoable semantic command:

```text
Add "centered horizontally" to circle at x = 7.4
  -> circle moves to x = 8.0
  -> one undo step: "Add Constraint"
```

**Conflicts are rejected at add time.** Because a satisfied constraint can never subsequently drift, conflict detection happens only at the moment of addition. A constraint that cannot coexist with an existing one is refused, with a message naming the conflicting constraint:

```text
Add "centered horizontally"
  refused: conflicts with "Fixed Distance to Handle",
  which already determines the horizontal position.
```

This design has three consequences worth stating plainly:

1. There is no violated, unresolved, or pending constraint state anywhere in the model.
2. Continuous constraint validation is unnecessary; §15.1's constraint category shrinks accordingly.
3. Constraint resolution is deterministic and cheap, because it never searches for a solution — it only restricts or projects.

### 11.3 Constraint UI

Constraints should be visible in the inspector and on canvas:

```text
Constraint: Centered horizontally
Constraint: Tangent to Outer Body
Constraint: Overshoot circle key shape by 0.25 units
```

Users should be able to:

- Add relationships from selected geometry.
- Disable a relationship.
- Convert a snapped placement into an explicit constraint.
- See why a constraint was refused.

## 12. Weight Masters and Scales

### 12.1 Authored Masters

The MVP supports three **authored** masters:

- Ultralight.
- Regular.
- Black.

Regular is the canonical editing master. All three are authored at **Medium scale only**.

### 12.2 Export Targets Three Slots, Not Twenty-Seven

Griddy exports **the three authored masters** into the three slots the SF Symbols authoring template provides, and runs a compatibility pass (§12.6) so those three interpolate correctly.

An earlier draft of this specification called for filling all 27 weight/scale slots directly, on the reasoning that if Apple never interpolates then boolean resolution's weight-dependent path structure would not matter. **That decision is withdrawn.** It was based on an assumption about the template format that turned out to be wrong. Two real templates settle it:

| | Authoring template | Static export |
|---|---|---|
| Artwork slots | 3 — `Ultralight-S`, `Regular-S`, `Black-S` | 27 — all weights × scales |
| Subpaths per slot | 6, identical across all 3 | 7, identical across all 27 |
| Path commands per slot | 70, identical across all 3 | 78, identical across all 27 |

Two things follow. The template the SF Symbols app exports for editing has **three** artwork slots, so there is nowhere to put 27 authored masters. And **every slot in both files carries identical path topology** — Apple's own fully-populated export holds subpath and command counts constant across all 27 variants, which is what one would expect if interpolation is central to the format rather than incidental.

Topology compatibility is therefore a real constraint on export, not something Griddy can design around. The export loop is:

```text
for each of the 3 authored masters:
    resolve constraints at that weight
    apply master adjustments
    outline primitives analytically   (§10.5)
    run boolean solver                (§10.5)

normalise the 3 resulting paths to a shared structure   (§12.6)
emit each into its slot
```

The cost is the compatibility pass. The benefit is that the geometry engine keeps its real boolean solver: booleans may produce whatever structure they produce, and reconciliation happens once, at the end, where it can be validated.

### 12.3 Weight Propagation

Non-authored weights derive their **parameters** — not their paths — by interpolating between the three authored masters. Parameter interpolation is safe precisely because path interpolation is not attempted: each slot is then solved independently from its own parameters.

```swift
struct WeightPropagationSettings: Codable, Equatable {
    var ultralightStrokeExpansion: Double
    var regularStrokeExpansion: Double
    var blackStrokeExpansion: Double
    var ultralightInteriorCompensation: Double
    var regularInteriorCompensation: Double
    var blackInteriorCompensation: Double
}
```

Example defaults:

```text
Stroke expansion
  Ultralight: 0.65
  Regular:    1.20
  Black:      2.35

Interior compensation
  Ultralight: 0.00
  Regular:    0.10
  Black:      0.45
```

The six intermediate weights (Thin, Light, Medium, Semibold, Bold, Heavy) interpolate these values piecewise between the authored anchors.

### 12.4 Scale Is Apple's To Derive

Scale is **not authored and not exported**. The authoring template's three slots are all at Small (`Ultralight-S`, `Regular-S`, `Black-S`); it provides no Medium or Large artwork slots at all. The SF Symbols app derives the other two scales, exactly as it derives the six intermediate weights.

The template does carry `Capline`/`Baseline` guides for all three scales, and measurement shows the cap height is identical across them — 70.459 template units at S, M and L in the templates examined. The scales therefore differ in vertical placement and in the margins around the artwork rather than in the size of the artwork itself.

This removes the scale-compensation factors an earlier draft called for, along with their open question. `SymbolMaster` still carries both a weight and a scale, so nothing in the model needs to change if per-scale authoring is ever wanted.

### 12.5 Construction Coherence

The construction must stay coherent across masters:

- Primitive count is stable across masters.
- Primitive identity is stable across masters.
- Per-master adjustments add or remove no primitives.
- Boolean operations resolve successfully at every authored weight.
- A boolean that resolves at one weight but fails at another is an error.

Warnings are raised when a per-master adjustment changes the *visual* structure — for example when a detail closes up entirely at Black, or a stroke collision appears only at heavy weights.

Note the distinction from path topology. Coherent *construction* is about the primitive graph and is enforced during editing. Compatible *path structure* is a property of the exported outlines and is produced at export time by §12.6. The first does not imply the second: two masters built from the same primitives can still resolve to different numbers of contours once booleans run.

### 12.6 Outline Compatibility Pass

Export must hand the SF Symbols app three masters that interpolate. After each master is outlined and boolean-resolved independently, they are normalised to a shared structure:

```text
input:  3 outline paths, structurally unrelated
        Ultralight  2 contours,  18 segments
        Regular     2 contours,  18 segments
        Black       3 contours,  27 segments   <- an extra contour

output: 3 outline paths with matching structure
        same contour count, same segment count per contour,
        same ordering, same start point per contour
```

The technique is the one variable-font tools use for compatible outlines:

1. **Pair contours across masters** by correspondence — position, area and winding — rather than by index, since boolean resolution does not guarantee stable ordering.
2. **Reconcile contour counts.** A contour present in one master and absent in another is the hard case: it means the shapes are genuinely topologically different, most often because a detail closes up at heavy weights. Insert a degenerate contour at the corresponding location so the counts match.
3. **Reconcile segment counts** within each paired contour by inserting redundant on-curve points, splitting existing segments at parameters chosen to correspond across masters. This changes the path's description but not the shape it describes.
4. **Align start points and direction** so contours traverse correspondingly.

Two things follow that the specification should be honest about. Step 2 can fail: when a detail genuinely disappears at one weight there is no honest correspondence, and the right response is an export-blocking error naming the primitive, not a silently invented contour. And step 3 increases node counts — the exported path is larger than the minimal outline the solver produced. That is the price of interpolability and is worth paying, but validation should report it.

> **Open Question:** Whether the SF Symbols app rejects mismatched masters outright, or accepts them and produces distorted intermediate weights, is not yet established. This decides whether §15 treats an unreconcilable master as an error or a warning. A round-trip through the real app settles it.

### 12.7 Interpolation Preview

The UI provides a slider or preview strip showing intermediate weights, rendered by solving that weight directly rather than by interpolating paths. This is a design and validation aid, and it is also the most direct check on the compatibility pass: if Griddy's own directly-solved intermediate weight and the interpolation implied by the three exported masters disagree visibly, the reconciliation is wrong.

## 13. Document Model

### 13.1 Native Package Format

Use a package directory:

```text
MySymbol.griddy/
  document.json
  geometry.json
  constraints.json
  masters.json
  previews/
  source-template.svg
  exports/
  metadata.json
```

SVG is an import/export format. `.griddy` is the source of truth.

A `.griddy` package describes **exactly one symbol**. It contains no references to other documents. Symbol comparison uses system SF Symbols instead (§8.3), which keeps the document self-contained and removes an entire class of broken-reference handling.

When reading a package, any file or JSON key that Griddy does not recognize is preserved and written back unchanged, so that a document touched by a newer version of Griddy does not lose that version's data (§13.3).

### 13.2 Root Document Structure

```swift
struct SymbolDocument: Codable, Identifiable {
    var id: UUID
    var metadata: SymbolMetadata
    var coordinateSystem: CoordinateSystem
    var grid: GridDefinition
    var keyShapes: KeyShapeSet
    var layers: [SymbolLayer]
    var primitives: [IconPrimitive]
    var constraints: [Constraint]
    var masters: [SymbolMaster]
    var previewSettings: PreviewSettings
    var exportSettings: ExportSettings
    var validationState: ValidationState
}
```

### 13.3 Metadata and Format Versioning

```swift
struct SymbolMetadata: Codable, Equatable {
    var name: String
    var bundleIdentifierHint: String?
    var author: String?
    var createdAt: Date
    var modifiedAt: Date
    var appVersion: String
    var documentFormatVersion: Int
    var designIntent: SymbolDesignIntent
}
```

Version handling is asymmetric, and deliberately so:

**Older documents migrate forward.** Migration runs as ordered steps (v2 → v3 → v4) on open. The pre-migration package is retained inside the document as a backup before the migrated form is written on next save, so a failed migration is recoverable.

**Newer documents are refused.** A document whose `documentFormatVersion` exceeds what the running build writes is not opened, partially parsed, or opened read-only. It is refused with a clear message:

```text
"CameraBadge.griddy" was created by a newer version of Griddy.
Update Griddy to open it.
```

Partially reading a document that cannot be fully understood risks showing the designer something subtly and silently wrong, which is worse than refusing to open it.

Combined with the unknown-key and unknown-file preservation in §13.1, this means a document can move between builds without silent data loss in either direction.

### 13.4 Layers

```swift
struct SymbolLayer: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var role: SymbolLayerRole
    var primitiveIDs: [PrimitiveID]
    var isVisible: Bool
    var isLocked: Bool
    var renderingRole: SymbolRenderingRole
}

enum SymbolLayerRole: String, Codable {
    case outerBody
    case detail
    case badge
    case cutout
    case annotation
}

enum SymbolRenderingRole: String, Codable {
    case monochrome
    case hierarchicalPrimary
    case hierarchicalSecondary
    case paletteLayer
    case multicolorLayer
}
```

The MVP should focus on monochrome. The rendering-role model exists to avoid painting the architecture into a corner.

### 13.5 Masters

```swift
struct SymbolMaster: Codable, Identifiable, Equatable {
    var id: UUID
    var weight: SymbolWeight
    var scale: SymbolScale
    var adjustments: [PrimitiveID: MasterAdjustment]
    var isDerived: Bool
}

enum SymbolWeight: String, Codable, CaseIterable {
    case ultralight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

enum SymbolScale: String, Codable, CaseIterable {
    case small
    case medium
    case large
}
```

In the MVP, exactly three `SymbolMaster` values have `isDerived == false`: Ultralight/Medium, Regular/Medium, Black/Medium. The remaining 24 slots are derived at export time (§12.2) and are not persisted as masters.

## 14. SF Symbols Import and Export

### 14.1 Import Requirements

Griddy imports SVG templates exported from Apple's SF Symbols app.

**Griddy targets exactly one template generation: v7.0**, the one exported by the current SF Symbols app. The importer reads the template's version marker and refuses anything else:

```text
"This template was exported by an older SF Symbols app.
 Re-export it from SF Symbols 6 or later."
```

Supporting a single template shape keeps the importer strict, the error messages sharp, and the exporter free of version branches — at the cost of requiring users to re-export old templates. Given that re-exporting is a few seconds of work in an app the user already has, this is a good trade.

Two shapes of v7.0 file exist, and the importer accepts both:

| | Authoring template | Static export |
|---|---|---|
| What it is | What the SF Symbols app exports for you to draw into | A dump of an existing symbol |
| Artwork slots | 3, at Small: `Ultralight-S`, `Regular-S`, `Black-S` | 27, all weights × scales |
| Griddy's use | The document being edited, and the export target | Reference geometry only |

Both carry the same `Notes` / `Guides` / `Symbols` group structure and the same guide set (`Baseline-S/M/L`, `Capline-S/M/L`, margin guides), so one extraction path handles both.

The importer should:

- Parse SVG using a structured XML parser.
- Preserve the original SVG verbatim as `source-template.svg`.
- Identify recognized SF Symbols groups and metadata.
- Extract paths into fallback primitives (§14.3).
- Warn on unsupported SVG features.
- Avoid silently discarding unknown template structure.
- Refuse elliptical arc path commands rather than approximating them, since an approximation silently alters imported geometry (§14.3).

### 14.2 Import Pipeline

```text
SVG file
  -> XML parse
  -> Template version check
  -> Template structure validation
  -> Coordinate-system extraction (baseline, capline, unit derivation)
  -> Layer/master extraction
  -> Imported-path records
  -> Griddy document package
```

This same pipeline runs for `Resources/BlankSymbolTemplate.svg` when creating a new document (§7.1).

### 14.3 Path-to-Primitive Inference

**Inference is never automatic.** All imported artwork lands as `ImportedPathPrimitive` and renders exactly as authored. Nothing is silently reinterpreted.

Converting an imported path into a semantic primitive is always an explicit user action on a selected path. The inspector offers the conversion and states the fit error up front, so the designer decides whether the approximation is acceptable:

```text
Selected: imported path
  Looks like a circle (fit error 0.02u)
  [Convert to Circle]
```

Griddy attempts to recognize circles, rounded rectangles, straight-line segments, arcs, and symmetry for the purpose of *offering* these conversions. It never applies them unprompted.

This follows directly from §6.1. A wrong inference rewrites the designer's geometry into something parametric but different — a silent corruption of exactly the intent the document exists to preserve. Faithful-but-dumb import is strictly better than clever-but-lossy import.

### 14.4 Export Requirements

The exporter should:

- Generate an SF Symbols-compatible SVG in the pinned template structure (§14.1).
- Preserve the required template hierarchy.
- Include required alignment and margin structure.
- Populate the template's three artwork slots (§12.2).
- Reconcile the three masters to a shared path structure so they interpolate (§12.6).
- Emit exact arcs and Béziers, never flattened polylines (§10.5).
- Retain a useful warning report.

### 14.5 Export Pipeline

```text
Griddy document
  -> for each of the 3 authored masters:
       resolve constraints at that weight
       apply per-master adjustments
       outline primitives analytically  (§10.5)
       run boolean solver               (§10.5)
  -> reconcile the 3 paths to a shared structure  (§12.6)
  -> emit each into its slot
  -> validate SVG template structure
  -> write SVG
  -> save export report
```

The three master solves are independent and may run concurrently. The reconciliation that follows is not: it needs all three at once, which is the one genuine barrier in the pipeline.

A failure in any single master fails the export, reported with the master identified, rather than producing a partially-populated template. A reconciliation that cannot be completed — because the masters are genuinely topologically different — fails the export naming the primitive responsible, rather than inventing a correspondence that does not exist (§12.6).

## 15. Validation

Validation runs continuously while designing and again at export time.

### 15.1 Validation Categories

#### Template Validation

- Required SVG groups are present.
- Template version matches the supported generation.
- Required slot groups exist.
- Template hierarchy is preserved.
- No unexpected destructive changes to metadata.

#### Geometry Validation

- Artwork is inside permitted bounds.
- Margins are present.
- No accidental open paths where closed paths are required.
- No invalid zero-length segments.
- No unsupported transforms in exported SVG.
- Boolean operations resolve successfully.

#### Constraint Validation

- Constraints resolve deterministically.

This category is deliberately small. Because constraints are invariants (§11.2), geometry cannot drift out of compliance, conflicts are rejected at add time, and there is no violated state to detect. The checks that earlier drafts listed here — "snapped geometry matches declared relationships", "no contradictory constraints" — are now structurally impossible to fail.

#### Construction Validation

- Primitive identities match across masters.
- Per-master adjustments add or remove no primitives.
- Booleans resolve at every authored master, not just Regular.

#### Interpolation Validation

Reinstated. An earlier draft dropped this category on the assumption that Griddy authored every exported slot and nothing interpolated; §12.2 withdraws that.

- The three masters reconcile to a shared path structure (§12.6).
- Contour counts correspond across masters.
- Segment counts and ordering match after reconciliation.
- Start points and traversal direction correspond.
- A master that cannot be reconciled is reported against the primitive responsible.
- Node count added by reconciliation is reported, since it inflates the exported path beyond the minimal outline.

#### Visual Validation

- Visual center deviation.
- Optical bounding box deviation.
- Small negative spaces.
- Stroke collisions at heavy weights.
- Detail loss at small sizes.
- Occupied area compared with selected key shape.

### 15.2 Validation Data Structure

```swift
struct ValidationIssue: Codable, Identifiable, Equatable {
    var id: UUID
    var severity: ValidationSeverity
    var category: ValidationCategory
    var message: String
    var affectedPrimitiveIDs: [PrimitiveID]
    var affectedMasterIDs: [UUID]
    var suggestedFix: String?
}

enum ValidationSeverity: String, Codable {
    case info
    case warning
    case error
}

enum ValidationCategory: String, Codable {
    case template
    case geometry
    case constraint
    case construction
    case visual
    case export
}

struct ValidationState: Codable, Equatable {
    var issues: [ValidationIssue]
    var lastValidatedAt: Date?
}
```

### 15.3 Validation Schedule

A full validation pass implies boolean resolution at three masters, a reconciliation across them, and rasterization, so it cannot run on every edit. But §6.5 requires continuous feedback. The resolution is tiering by cost, not reducing frequency.

| Tier | When | Where | Checks |
|---|---|---|---|
| 1 | Every edit, synchronously | Main actor | Bounds, margins, zero-length segments, open/closed paths. Target under 1 ms. |
| 2 | Debounced 250 ms after edits settle | Background | Boolean resolution at the three authored masters, visual center, optical bounds, raster previews, stroke collision, negative space. |
| 3 | Export only | Background | Three-master solve, outline compatibility pass, template structure validation, export report. |

Rules:

- Tier 1 must never allocate significantly or touch the boolean solver.
- Tier 2 results publish when ready and never block the canvas. A newer edit supersedes an in-flight pass.
- The bottom strip shows the last known Tier 2 result while a new pass runs, dimmed, rather than blanking (§8.7).
- Tier 3 runs only on explicit export and may show progress.

This schedule is the primary reason the geometry, constraint, and validation code lives outside the app target (§16.1) — the app target defaults every type to `@MainActor`, which would pin Tier 2 to the main thread and stutter the canvas.

## 16. Architecture

### 16.1 Recommended Technology

- **Language:** Swift 6.2.
- **Minimum OS:** macOS 26.
- **UI:** SwiftUI for app chrome, sidebars, inspectors, settings, and commands.
- **Canvas:** Custom `NSView` or SwiftUI `Canvas` backed by Core Graphics.
- **Rendering:** Core Graphics paths.
- **Persistence:** File package via `DocumentGroup` with a `ReferenceFileDocument`.
- **Parsing:** XML parser for SVG import/export.
- **Undo:** `UndoManager` with semantic commands.
- **Testing:** Swift Testing.

Do not start with SceneKit or Metal. The hard problems are geometry, hit testing, constraints, booleans, validation, and export fidelity.

**Actor isolation is a real constraint here.** The Xcode project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so every type in the app target is implicitly main-actor-isolated. That is correct for UI and wrong for a geometry engine that must run Tier 2 validation off the main thread (§15.3). The non-UI code therefore lives in local Swift packages that opt out of that default:

```swift
swiftSettings: [.defaultIsolation(nil)]
```

**Reuse what is already linked.** `CGMath` and `MathKit` are existing project dependencies and already covered in the About box attributions. Vector, matrix, and geometric primitives should come from those rather than being reimplemented.

### 16.2 Modules

Non-UI code lives in `Packages/` as local Swift packages, each with its own test target. UI and rendering stay in the app target, where the MainActor default is appropriate.

```text
Packages/
  AppDesign          Design tokens and styling (exists, currently a shell)
  GriddyGeometry     Primitives, outlining, boolean solver, transforms, hit testing
  GriddyConstraints  Constraint records, degree-of-freedom restriction, conflict detection
  GriddyDocument     Codable models, package read/write, migrations
  GriddySymbols      SF Symbols template import/export, SVG parse/write
  GriddyValidation   Template, geometry, construction, and visual checks
  GriddyTestSupport  Fixtures, comparison helpers, golden SVG helpers

Griddy/ (app target)
  App scenes, commands, sidebar, canvas, inspector, preview strip, rendering
```

Dependency direction, strictly one-way:

```text
GriddyGeometry
  <- GriddyConstraints
  <- GriddyDocument
  <- GriddySymbols
  <- GriddyValidation
  <- app target
```

`GriddyGeometry` depends on nothing but `CGMath` and `MathKit`. This keeps the hardest, most test-sensitive code — outlining and booleans — buildable and testable in isolation, without launching the app.

### 16.3 Internal Data Flow

```text
User action
  -> Semantic edit command
  -> Constraint restriction applied to input
  -> Document model mutation
  -> Geometry cache update
  -> Renderer update
  -> Tier 1 validation (sync)
  -> Tier 2 validation (debounced, background)
  -> Preview update
```

Note that constraint handling appears *before* the mutation, not after. This is the §11.2 invariant model expressed as data flow.

### 16.4 Undo Architecture

All edits are semantic commands:

- Add primitive.
- Move primitive.
- Change radius.
- Add constraint.
- Remove constraint.
- Adjust weight master.
- Change layer role.
- Import template.

Avoid storing undo as raw path snapshots except as a fallback for imported paths.

**Continuous interactions are gesture-scoped.** Views open and close an explicit interaction boundary, and everything inside becomes one named undo step:

```text
mouseDown  -> beginUndoGrouping("Move Outer Body")
drag x120  -> mutations, no new undo steps
mouseUp    -> endUndoGrouping
```

Rules:

- Any geometry moved by constraint restriction during the gesture belongs to the same step.
- Adding a constraint, and the compliance snap it causes, is one step (§11.2).
- Text fields commit one step on blur or return, not per keystroke.
- Steppers and sliders coalesce for the duration of the interaction.

Time-window coalescing is explicitly rejected: it splits slow deliberate drags into several steps and merges quick separate edits into one, which makes undo unpredictable.

## 17. Repository Structure

The project is an Xcode project with local Swift packages, not a flat source tree. The app target uses `PBXFileSystemSynchronizedRootGroup`, so adding, removing, and renaming Swift files requires no project file edits.

```text
Griddy/
  Griddy.xcodeproj
  Griddy/                              app target sources
    macOS/
      MacApp.swift                     @main, scene registration
      MacAppDelegate.swift
      Info.plist                       Sparkle keys + document types
      App Environment/                 dependency container
      Document Window/
        DocumentWindow.swift
        DocumentCommands.swift
      Sidebar/
      Canvas/
        CanvasView.swift
        ConstructionLayerRenderer.swift
        ArtworkLayerRenderer.swift
        EvaluationLayerRenderer.swift
      Inspector/
        GeometryInspector.swift
        ConstraintInspector.swift
        MasterInspector.swift
        ExportInspector.swift
      Bottom Strip/
        ValidationStatusView.swift
        PreviewStripView.swift
      Settings/
      Help Window/
      Utilities/
    All Platforms/
      Infrastructure/Settings/         AppSettings + KeyValueStore
      App Information/
      Utilities/
    Resources/
      DefaultKeyShapes.json
      BlankSymbolTemplate.svg
      PreviewContexts.json
    Assets.xcassets/
    scripts/
  Packages/
    AppDesign/
    GriddyGeometry/
    GriddyConstraints/
    GriddyDocument/
    GriddySymbols/
    GriddyValidation/
    GriddyTestSupport/
  Docs/
```

Conversion notes for the existing boilerplate:

- `MacApp.swift` currently registers a `WindowGroup`. It must become a `DocumentGroup` over the `.griddy` package type.
- `MainWindow.swift` contains `CommandGroup(replacing: .newItem, addition: { })`, which suppresses **New**. This must be removed for a document app.
- Document type declarations (`CFBundleDocumentTypes`, `UTExportedTypeDeclarations`) go in `Griddy/macOS/Info.plist`, which currently holds only Sparkle keys.
- The sandbox is already enabled with `ENABLE_USER_SELECTED_FILES = readwrite`, which is what a document app needs.
- `.swiftlint.yml` is an allowlist that enables `force_unwrapping` and `force_try`. No `!` unwraps and no `try!` in new code.

## 18. MVP Scope

The first version should be disciplined and narrow.

### Included

1. Create and save `.griddy` document packages.
2. Import an editable SF Symbols SVG template of the supported generation.
3. Edit the Regular master using:
   - Lines.
   - Arcs.
   - Circles.
   - Rounded rectangles.
   - Capsules.
   - Symmetric paths.
4. Display:
   - Primary grid.
   - Secondary grid.
   - Safe area.
   - Margins.
   - Baseline.
   - Configurable key shapes.
5. Author Ultralight and Black masters at Medium scale.
6. Allow per-master optical adjustments.
7. Preview weight interpolation.
8. Preview common point sizes.
9. Validate bounds, margins, construction coherence, and template structure.
10. Export an SVG with the three authored masters reconciled so they interpolate.

### Excluded

- Multicolor symbol authoring.
- Animation annotations.
- Manual editing of the six intermediate weights. They are derived (§12.3).
- Manual editing of the Small and Large scales. They are derived (§12.4).
- Library/team management.
- Plugin system.
- Cloud sync.
- Collaboration.
- Text and typography tooling.
- Advanced arbitrary Bézier editing as a primary workflow.

The MVP authors three masters at one scale and exports exactly those three. The remaining weights and both other scales are derived by the SF Symbols app, not by Griddy (§12.2, §12.4).

## 19. Milestones

### Milestone 1: Project Foundation

Deliverables:

- Convert the boilerplate from `WindowGroup` to `DocumentGroup`.
- Local Swift packages created with test targets.
- `.griddy` package read/write.
- Basic document model.
- Empty canvas with grid and key-shape rendering.
- Unit tests for document encoding and decoding.

Acceptance criteria:

- User can create, save, close, and reopen a `.griddy` document.
- A new document derives its coordinate system from the bundled blank template.
- Default grid and key shapes render.
- Document format version is stored.

### Milestone 2: Canvas and Primitive Editing

Deliverables:

- Selection model.
- Add, move, and delete primitives.
- Line, circle, arc, rounded rectangle, and capsule tools.
- Inspector for selected primitive properties.
- Gesture-scoped undo/redo for semantic edits.

Acceptance criteria:

- User can construct a simple icon using only primitives.
- Inspector edits update the canvas immediately.
- A drag is exactly one undo step.

### Milestone 3: Outlining and Booleans

Deliverables:

- Analytic outliner for every primitive kind.
- Curve-curve boolean solver with union, subtract, and intersect.
- Filled artwork rendering on canvas.
- Extensive geometry unit tests.

Acceptance criteria:

- Every primitive outlines correctly at a range of stroke widths.
- Overlapping primitives union into a correct, minimal outline.
- Outlines contain exact curves, not flattened polylines.

This milestone is deliberately placed before constraints. It is the highest-risk work in the project, and everything downstream depends on it.

### Milestone 4: Constraints

Deliverables:

- Snap to grid and key shapes.
- Degree-of-freedom restriction during drags.
- Explicit constraints for centering, equal radius, tangent, concentric, symmetry, parallel, and perpendicular.
- Add-time compliance snapping and conflict rejection.
- Constraint display in the inspector.

Acceptance criteria:

- Constrained geometry cannot be dragged out of compliance.
- Adding a constraint moves geometry and records the constraint as one undo step.
- A conflicting constraint is refused with the conflict named.

### Milestone 5: SF Symbols Import

Deliverables:

- SVG parser.
- Template version check and validator.
- Coordinate-system extraction.
- Source template preservation.
- Fallback path rendering and opt-in conversion.

Acceptance criteria:

- App imports a template exported from the supported SF Symbols app version.
- An unsupported template version is refused with a clear message.
- Imported artwork renders faithfully and is never silently converted.

### Milestone 6: Masters and Slot Derivation

Deliverables:

- Ultralight, Regular, and Black authored masters.
- Weight propagation settings and parameter interpolation.
- Scale derivation rules.
- Per-master primitive adjustments.
- Interpolation preview.

Acceptance criteria:

- Three authored masters export into the template's three slots.
- Per-master adjustments do not break primitive identity.
- Warnings appear when a detail closes or strokes collide at heavy weights.

### Milestone 7: Validation, Preview, and Export

Deliverables:

- Three-tier validation engine.
- Bottom validation strip with staleness handling.
- Small-size previews.
- SF Symbols SVG exporter writing the three authored masters.
- Outline compatibility pass reconciling the masters (§12.6).
- Export validation report.
- Golden SVG round-trip fixtures.

Acceptance criteria:

- Tier 1 validation is imperceptible during editing.
- Tier 2 results appear shortly after edits settle without stuttering the canvas.
- User sees export-blocking errors before export.
- Exported fixtures import successfully into Apple's SF Symbols app.
- The §12.6 Open Question is resolved by actual round-trip: whether mismatched masters are rejected or silently distorted.

## 20. Acceptance Criteria for MVP

The MVP is complete when:

1. A user can create a new `.griddy` document.
2. A user can import an SF Symbols SVG template of the supported generation.
3. A user can draw a simple monochrome line-art symbol using semantic primitives.
4. The canvas displays grid, safe area, margins, baseline, and key shapes derived from the template.
5. The inspector exposes semantic properties for selected primitives.
6. Constraints restrict geometry and cannot be violated.
7. The app exports three authored masters whose paths interpolate.
8. The user can apply per-master optical adjustments.
9. The app detects bounds, construction, and visual problems without stalling the canvas.
10. The app previews the symbol at common small sizes.
11. The app exports an SVG intended for Apple's SF Symbols app.
12. Representative exported fixtures import successfully into Apple's SF Symbols app.
13. All document round-trip, geometry, outlining, boolean, validation, and SVG export tests pass.

## 21. Testing Strategy

There is currently **no test target anywhere in the repository.** Each local package created in §16.2 carries its own test target from the start.

### 21.1 Unit Tests

Cover:

- Document encoding and decoding.
- Package read/write and migration.
- Geometry primitive construction.
- **Outlining, per primitive kind, across a range of stroke widths.**
- **Boolean union, subtract, and intersect, including tangential and degenerate cases.**
- Coordinate transforms and unit derivation.
- Hit testing.
- Constraint restriction and conflict rejection.
- Validation rules.
- SVG parsing and writing.

Outlining and booleans deserve disproportionate test weight. They are the least visually obvious code in the project and the code every export depends on.

### 21.2 Fixture Tests

Maintain fixtures:

- Blank templates.
- Imported SF Symbols templates.
- Unsupported template versions.
- Simple valid symbols.
- Known invalid template structures.
- Out-of-bounds artwork.
- Stroke collision cases.
- Boolean edge cases: tangential contact, coincident edges, fully-contained shapes.

Each fixture defines expected validation results and, where applicable, expected export structure.

### 21.3 Golden SVG Tests

For stable export cases:

- Export a known `.griddy` fixture.
- Normalize SVG formatting.
- Compare against expected SVG.

Use normalized comparisons rather than raw string comparisons where attribute order is not meaningful.

### 21.4 Visual Regression Tests

Generate raster previews at common point sizes and compare:

- Bounds.
- Non-empty output.
- Expected approximate pixel coverage.
- Absence of severe clipping.

### 21.5 Manual QA

For each release candidate:

1. Create a new symbol from scratch.
2. Import a template from Apple's SF Symbols app.
3. Draw a representative symbol.
4. Generate weights.
5. Export SVG.
6. Import into Apple's SF Symbols app.
7. Verify expected warnings and errors.

## 22. Risks and Mitigations

### Risk: Outlining and Boolean Correctness

This is the highest-risk area in the project. Boolean solvers fail on tangential contact, coincident edges, and near-degenerate curves, and the failures are subtle.

Mitigation:

- Build it early, in Milestone 3, before anything depends on it in anger.
- Keep it in an isolated package with no UI dependencies.
- Disproportionate unit test coverage, including degenerate cases.
- Prefer exact analytic constructions over numerical approximation wherever a closed form exists.

### Risk: SF Symbols Template Compatibility

Apple's SVG template requirements may change. This risk has already materialised once: an earlier draft of §12.2 rested on an assumption about the template format that two real exports disproved, and the export strategy had to be rewritten. The lesson is that assumptions about this format must be checked against real files rather than reasoned about.

Mitigation:

- Keep importer/exporter isolated in `GriddySymbols`.
- Preserve unknown SVG metadata where possible.
- Resolve the §12.6 Open Question by real round-trip before Milestone 7 closes.
- Treat Apple's SF Symbols app as the final compatibility authority.
- Pin one template generation (§14.1) rather than guessing at compatibility across several.

### Risk: Validation Cost

A full validation pass implies three boolean solves, a reconciliation across them, and rasterization.

Mitigation:

- Tier validation by cost (§15.3).
- Keep geometry code off the main actor (§16.1).
- Never block the canvas on validation; show stale results instead.

### Risk: Over-expanding into a General Vector Editor

Feature pressure may dilute the product.

Mitigation:

- Keep non-goals explicit.
- Prioritize SF Symbols validation and weight propagation.
- Make semantic primitive editing better before adding arbitrary path editing.
- Note that the boolean solver is infrastructure, not a user-facing vector feature.

### Risk: Small Details Fail at Heavy Weights or Small Sizes

Icons may look valid at large sizes but collapse in real UI contexts.

Mitigation:

- Keep small-size previews always visible.
- Add stroke collision checks.
- Add negative-space checks.
- Provide blur/visual-stain preview.

### Risk: Imported Paths Are Hard to Make Semantic

Existing SVGs may contain arbitrary path data.

Mitigation:

- Support fallback imported paths as first-class, exportable geometry.
- Offer inference as an explicit, reviewable conversion (§14.3).
- Let users redraw over imported references.

## 23. Implementation Notes for a Coding Agent

### 23.1 Build Order

Recommended order:

1. Convert the boilerplate to a document app; create the local packages.
2. Implement Codable document models and package read/write.
3. Render the canvas grid and key shapes from template-derived coordinates.
4. Add the primitive model and centerline renderer.
5. **Implement analytic outlining and the boolean solver.**
6. Add selection, inspector, and gesture-scoped undo.
7. Add constraints as degree-of-freedom restriction.
8. Add the tiered validation engine.
9. Add SVG import.
10. Add masters and slot derivation.
11. Add the outline compatibility pass and SVG export.

### 23.2 Early Technical Decisions

- Keep Core Graphics path generation separate from model types.
- Do not let UI state become the document model.
- Use stable IDs for all primitives and layers.
- Make validation pure where possible.
- Store source SVG templates untouched.
- Cache generated paths, but always be able to regenerate them from semantic data.
- Mark geometry packages as non-MainActor-isolated from the first commit, not retroactively.

### 23.3 Performance Expectations

Typical documents will be small. Prefer correctness and inspectability over premature optimization.

Cache:

- Resolved constraints.
- Outlined primitives.
- Boolean results, keyed by weight.
- Raster previews.
- Validation results.

Invalidate caches when:

- Primitive geometry changes.
- Constraints change.
- Master adjustments change.
- Grid or coordinate system changes.
- Export settings change.

Boolean results must be keyed by weight, since they are weight-dependent (§10.5).

## 24. Future Features

Possible post-MVP additions:

- Manual editing of all nine weights and three scales.
- Per-scale master overrides.
- Multicolor and palette rendering semantics.
- Advanced node-editing mode.
- Symbol family comparison across documents.
- Library browser.
- Batch validation and export.
- Command-line exporter (`griddytool`).
- Design-system reports.
- Shared key-shape presets.
- Better primitive inference from arbitrary SVG.
- AppleScript or Shortcuts support.
- Preview against live app typography metrics.

## 25. Glossary

- **Authored master:** One of the three weight variants the designer edits directly (Ultralight, Regular, Black, all at Medium scale).
- **Derived slot:** One of the 24 weight/scale combinations the SF Symbols app produces from the three exported masters.
- **Primitive:** A semantic geometry object such as a circle, line, or arc.
- **Outlining:** Converting a stroked centerline into a closed, filled outline.
- **Constraint:** A declared geometric relationship, treated as an invariant.
- **Key shape:** A guide shape used to harmonize icon proportions.
- **Optical correction:** A small deliberate deviation from mathematical alignment for visual balance.
- **Template:** An SVG exported from Apple's SF Symbols app.
- **Unit (u):** One sixteenth of the template's cap height.
- **Visual center:** Perceived center of mass of the rendered icon.
- **Safe area:** Region where artwork should generally remain.

## 26. Summary

Griddy should be a small, opinionated, native macOS tool that helps designers create valid custom SF Symbols by working with the structure of icon design rather than against it. The product succeeds if it makes well-proportioned, interoperable, grid-based, weight-aware symbols easier to create than they are in general-purpose vector tools.

Two implementation choices matter more than the rest. The first is that the native document model is semantic and parametric: SVG import/export is essential, but SVG does not define the app's internal truth. The second is that Griddy owns its geometry pipeline end to end — analytic outlining and a real boolean solver — and reconciles its three exported masters itself rather than hoping they happen to interpolate.
