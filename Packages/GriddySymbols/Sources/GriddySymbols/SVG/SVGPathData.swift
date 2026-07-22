//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import Foundation
import GriddyGeometry

/// One command from an SVG path's `d` attribute, resolved to absolute
/// coordinates.
///
/// Cubic curves are kept as cubics. Griddy's own outlines are lines and arcs
/// only, which is what keeps boolean intersection analytic, but imported
/// artwork is not authored geometry: it renders and exports faithfully and is
/// never fed to the solver. Flattening it here to fit the outline vocabulary
/// would silently alter a designer's shapes, which spec 14.3 forbids.
public enum SVGPathCommand: Hashable, Sendable {

    case move(to: IconPoint)
    case line(to: IconPoint)
    case cubic(control1: IconPoint, control2: IconPoint, to: IconPoint)
    case close
}

public enum SVGPathParseError: Error, Equatable, LocalizedError {

    case unexpectedCharacter(Character)
    case missingOperands(command: Character)
    case unsupportedCommand(Character)

    public var errorDescription: String? {
        switch self {
        case .unexpectedCharacter(let character):
            "Unexpected character '\(character)' in path data."
        case .missingOperands(let command):
            "The '\(command)' command is missing operands."
        case .unsupportedCommand(let command):
            "Path command '\(command)' is not supported."
        }
    }
}

/// Parses the `d` attribute of an SVG path.
///
/// Covers the command set Apple's templates use, plus the shorthand forms, and
/// refuses anything else rather than guessing. Elliptical arcs (`A`) are
/// explicitly unsupported: approximating them would change the geometry, and
/// silently altering imported artwork is exactly what spec 14.3 rules out.
public enum SVGPathData {

    public static func parse(_ data: String) throws -> [SVGPathCommand] {
        var scanner = Scanner(data)
        var commands: [SVGPathCommand] = []

        var current = IconPoint.zero
        var subpathStart = IconPoint.zero
        var previousControl: IconPoint?
        var previousCommand: Character?

        while let command = try scanner.nextCommand(repeating: previousCommand) {
            let isRelative = command.isLowercase
            let letter = Character(command.uppercased())

            func point(_ x: Double, _ y: Double) -> IconPoint {
                isRelative ? IconPoint(x: current.x + x, y: current.y + y)
                           : IconPoint(x: x, y: y)
            }

            switch letter {
            case "M":
                let target = point(try scanner.number(letter), try scanner.number(letter))
                commands.append(.move(to: target))
                current = target
                subpathStart = target
                previousControl = nil
                // Further coordinate pairs after a moveto are implicit linetos.
                previousCommand = isRelative ? "l" : "L"
                continue

            case "L":
                let target = point(try scanner.number(letter), try scanner.number(letter))
                commands.append(.line(to: target))
                current = target
                previousControl = nil

            case "H":
                let x = try scanner.number(letter)
                let target = IconPoint(x: isRelative ? current.x + x : x, y: current.y)
                commands.append(.line(to: target))
                current = target
                previousControl = nil

            case "V":
                let y = try scanner.number(letter)
                let target = IconPoint(x: current.x, y: isRelative ? current.y + y : y)
                commands.append(.line(to: target))
                current = target
                previousControl = nil

            case "C":
                let c1 = point(try scanner.number(letter), try scanner.number(letter))
                let c2 = point(try scanner.number(letter), try scanner.number(letter))
                let target = point(try scanner.number(letter), try scanner.number(letter))
                commands.append(.cubic(control1: c1, control2: c2, to: target))
                current = target
                previousControl = c2

            case "S":
                // Smooth cubic: the first control point mirrors the previous one.
                let c2 = point(try scanner.number(letter), try scanner.number(letter))
                let target = point(try scanner.number(letter), try scanner.number(letter))
                let c1 = reflect(previousControl, about: current)
                commands.append(.cubic(control1: c1, control2: c2, to: target))
                current = target
                previousControl = c2

            case "Q":
                let control = point(try scanner.number(letter), try scanner.number(letter))
                let target = point(try scanner.number(letter), try scanner.number(letter))
                commands.append(elevated(from: current, control: control, to: target))
                current = target
                previousControl = control

            case "T":
                let control = reflect(previousControl, about: current)
                let target = point(try scanner.number(letter), try scanner.number(letter))
                commands.append(elevated(from: current, control: control, to: target))
                current = target
                previousControl = control

            case "Z":
                commands.append(.close)
                current = subpathStart
                previousControl = nil

            default:
                throw SVGPathParseError.unsupportedCommand(command)
            }

            previousCommand = command
        }

        return commands
    }

    /// A control point reflected through the current point, for the smooth
    /// shorthand commands. With no previous control the curve starts straight.
    private static func reflect(_ control: IconPoint?,
                                about point: IconPoint) -> IconPoint {
        guard let control else {
            return point
        }
        return IconPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    /// A quadratic raised to an equivalent cubic, so downstream code has one
    /// curve kind to handle rather than two.
    private static func elevated(from start: IconPoint,
                                 control: IconPoint,
                                 to end: IconPoint) -> SVGPathCommand {
        let c1 = IconPoint(x: start.x + 2.0 / 3.0 * (control.x - start.x),
                           y: start.y + 2.0 / 3.0 * (control.y - start.y))
        let c2 = IconPoint(x: end.x + 2.0 / 3.0 * (control.x - end.x),
                           y: end.y + 2.0 / 3.0 * (control.y - end.y))
        return .cubic(control1: c1, control2: c2, to: end)
    }
}

// MARK: - Scanning

private struct Scanner {

    private let characters: [Character]
    private var index: Int = 0

    init(_ string: String) {
        characters = Array(string)
    }

    private var isAtEnd: Bool {
        index >= characters.count
    }

    private mutating func skipSeparators() {
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace || character == "," {
                index += 1
            } else {
                break
            }
        }
    }

    /// The next command letter, or a repeat of the previous one when the data
    /// continues with bare operands.
    mutating func nextCommand(repeating previous: Character?) throws -> Character? {
        skipSeparators()
        guard !isAtEnd else {
            return nil
        }

        let character = characters[index]
        if character.isLetter {
            index += 1
            return character
        }
        // A digit here means another run of operands for the previous command.
        if character.isNumber || character == "-" || character == "+" || character == "." {
            guard let previous else {
                throw SVGPathParseError.unexpectedCharacter(character)
            }
            return previous
        }
        throw SVGPathParseError.unexpectedCharacter(character)
    }

    mutating func number(_ command: Character) throws -> Double {
        skipSeparators()

        var text = ""
        var seenDigit = false

        while index < characters.count {
            let character = characters[index]

            if character.isNumber {
                seenDigit = true
            } else if character == "-" || character == "+" {
                // A sign is only part of this number at its start, or straight
                // after an exponent; otherwise it begins the next number.
                let isExponentSign = text.last == "e" || text.last == "E"
                if !text.isEmpty && !isExponentSign {
                    break
                }
            } else if character == "." {
                // A second dot belongs to the next number.
                if text.contains(".") || text.lowercased().contains("e") {
                    break
                }
            } else if character == "e" || character == "E" {
                if !seenDigit {
                    break
                }
            } else {
                break
            }

            text.append(character)
            index += 1
        }

        guard seenDigit, let value = Double(text) else {
            throw SVGPathParseError.missingOperands(command: command)
        }
        return value
    }
}
