//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddyGeometry

@Suite("Primitive handles")
struct PrimitiveHandleTests {

    @Test("A circle exposes a centre handle and a radius handle")
    func circleHandles() {
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 5, y: 5), radius: 3))
        let handles = circle.handles
        #expect(handles.count == 2)
        #expect(handles.contains { $0.handle == .center
                                   && $0.position == IconPoint(x: 5, y: 5) })
        #expect(handles.contains { $0.handle == .radius
                                   && $0.position == IconPoint(x: 8, y: 5) })
    }

    @Test("Dragging the centre handle moves the circle without resizing")
    func dragCircleCentre() {
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 5, y: 5), radius: 3))
        let moved = circle.moving(.center, to: IconPoint(x: 10, y: 2))
        #expect(moved.anchor == IconPoint(x: 10, y: 2))
        #expect(moved.radius == 3)
    }

    @Test("Dragging the radius handle resizes the circle")
    func dragCircleRadius() {
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: IconPoint(x: 0, y: 0), radius: 3))
        let resized = circle.moving(.radius, to: IconPoint(x: 5, y: 0))
        #expect(resized.radius == 5)
        // The centre does not move.
        #expect(resized.anchor == IconPoint(x: 0, y: 0))
    }

    @Test("Dragging a line endpoint moves only that end")
    func dragLineEnd() {
        let line = IconPrimitive.line(LinePrimitive(
            start: IconPoint(x: 0, y: 0), end: IconPoint(x: 4, y: 0)))
        let moved = line.moving(.lineEnd, to: IconPoint(x: 4, y: 6))
        guard case .line(let updated) = moved else {
            Issue.record("not a line"); return
        }
        #expect(updated.start == IconPoint(x: 0, y: 0))
        #expect(updated.end == IconPoint(x: 4, y: 6))
    }

    @Test("Dragging a rectangle corner keeps the opposite corner fixed")
    func dragRectCorner() {
        let rect = IconPrimitive.roundedRect(RoundedRectPrimitive(
            bounds: IconRect(x: 0, y: 0, width: 4, height: 4), cornerRadius: 1))
        // topRight is (maxX, maxY) = (4, 4); its opposite bottomLeft (0,0) stays.
        let resized = rect.moving(.corner(.topRight), to: IconPoint(x: 6, y: 8))
        guard case .roundedRect(let updated) = resized else {
            Issue.record("not a rect"); return
        }
        #expect(updated.bounds == IconRect(x: 0, y: 0, width: 6, height: 8))
    }

    @Test("Dragging a corner past its opposite flips without going negative")
    func dragRectCornerPastOpposite() {
        let rect = IconPrimitive.roundedRect(RoundedRectPrimitive(
            bounds: IconRect(x: 0, y: 0, width: 4, height: 4), cornerRadius: 1))
        // Drag topRight to the far side of bottomLeft: bounds stay positive.
        let resized = rect.moving(.corner(.topRight), to: IconPoint(x: -3, y: -2))
        guard case .roundedRect(let updated) = resized else {
            Issue.record("not a rect"); return
        }
        #expect(updated.bounds.size.width == 3)
        #expect(updated.bounds.size.height == 2)
    }

    @Test("The corner-radius handle sets the corner radius")
    func dragCornerRadius() {
        let rect = IconPrimitive.roundedRect(RoundedRectPrimitive(
            bounds: IconRect(x: 0, y: 0, width: 10, height: 10), cornerRadius: 1))
        let updated = rect.moving(.cornerRadius, to: IconPoint(x: 3, y: 10))
        #expect(updated.cornerRadius == 3)
    }

    @Test("Dragging an arc endpoint changes its angle, not its radius")
    func dragArcEnd() {
        let arc = IconPrimitive.arc(ArcPrimitive(
            center: IconPoint(x: 0, y: 0), radius: 5,
            startAngle: IconAngle(radians: 0),
            endAngle: IconAngle(radians: .pi / 2)))
        // Drag the end toward the -x direction; angle becomes ~pi, radius kept.
        let updated = arc.moving(.arcEnd, to: IconPoint(x: -10, y: 0))
        #expect(updated.radius == 5)
        guard case .arc(let a) = updated else { Issue.record("not arc"); return }
        #expect(abs(a.endAngle.radians - .pi) < 1e-9)
    }

    @Test("Dragging a polyline vertex moves just that point")
    func dragPolylineVertex() {
        let polyline = IconPrimitive.polyline(PolylinePrimitive(
            points: [IconPoint(x: 0, y: 0), IconPoint(x: 1, y: 1),
                     IconPoint(x: 2, y: 0)], isClosed: false))
        let moved = polyline.moving(.vertex(1), to: IconPoint(x: 1, y: 5))
        guard case .polyline(let p) = moved else { Issue.record("not polyline"); return }
        #expect(p.points[1] == IconPoint(x: 1, y: 5))
        #expect(p.points[0] == IconPoint(x: 0, y: 0))
    }

    @Test("Compounds and imported paths expose no reshape handles")
    func noHandlesForOpaqueKinds() {
        let compound = IconPrimitive.compound(
            CompoundPrimitive(operation: .union, children: []))
        #expect(compound.handles.isEmpty)
    }

    @Test("A wrong handle for the kind is a no-op")
    func mismatchedHandleIsIgnored() {
        let circle = IconPrimitive.circle(
            CirclePrimitive(center: .zero, radius: 3))
        // A line handle on a circle changes nothing.
        #expect(circle.moving(.lineStart, to: IconPoint(x: 9, y: 9)) == circle)
    }
}
