//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct MyDataEntry {
    let name: String
    let number: Int
}

struct MyExportDocument: FileDocument {
    
    static let readableContentTypes = [UTType.tabSeparatedText]

    // swiftlint:disable force_unwrapping
    private let newline = "\n".data(using: .utf8)!
    private let delimiter = "\t".data(using: .utf8)!
    // swiftlint:enable force_unwrapping

    let entries: [MyDataEntry]

    init(entries: [MyDataEntry]) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        self.init(entries: [])
        // TODO: Implement import
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        
        var data = Data()

        append("Name", to: &data)
        append(delimiter, to: &data)
        append("Number", to: &data)
        append(delimiter, to: &data)

        for entry in entries {
            append(entry.name, to: &data)
            append(delimiter, to: &data)
            append(entry.number, to: &data)
            append(newline, to: &data)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }

    private func append(_ newData: Data, to data: inout Data) {
        data.append(newData)
    }

    private func append<S: StringProtocol>(_ string: S, to data: inout Data) {
        guard let stringData = string.data(using: .utf8) else {
            return
        }
        data.append(stringData)
    }

    private func append(_ number: Int, to data: inout Data) {
        append("\(number)", to: &data)
    }
}
