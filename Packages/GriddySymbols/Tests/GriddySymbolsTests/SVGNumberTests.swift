//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Testing
import Foundation
@testable import GriddySymbols

@Suite("Coordinate formatting")
struct SVGNumberTests {

    @Test("Precision is decimal places, not significant digits")
    func largeValuesKeepTheirFraction() {
        // The bug: %.4g gave four significant digits, so a margin guide at
        // 1210.34 was written "1210" -- rounded to the nearest template unit.
        // Exported side bearings scattered by up to half a unit as a result.
        #expect(SVGPathWriter.number(1210.34) == "1210.34")
        #expect(SVGPathWriter.number(2871.7125) == "2871.7125")
        #expect(SVGPathWriter.number(1391.2) == "1391.2")
    }

    @Test("Whole numbers stay whole and fractions lose trailing zeros")
    func staysCompact() {
        #expect(SVGPathWriter.number(263) == "263")
        #expect(SVGPathWriter.number(-8) == "-8")
        #expect(SVGPathWriter.number(9.7656) == "9.7656")
        #expect(SVGPathWriter.number(9.5000) == "9.5")
        #expect(SVGPathWriter.number(0.1) == "0.1")
    }

    @Test("Rounding happens at four decimals")
    func roundsAtFourDecimals() {
        #expect(SVGPathWriter.number(9.76562) == "9.7656")
        #expect(SVGPathWriter.number(1.00001) == "1")
    }
}
