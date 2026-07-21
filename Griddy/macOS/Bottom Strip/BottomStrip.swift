//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyDocument

/// The validation and preview strip along the bottom of the document window.
///
/// Milestone 1 shows the strip's structure with the validation engine not yet
/// wired up. Tiered validation arrives in Milestone 7. See spec 8.7 and 15.3.
struct BottomStrip: View {

    let document: SymbolDocument

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            validationSection
            Divider()
            previewSection
        }
        .frame(height: 150)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Validation")

            if document.validationState.issues.isEmpty {
                Label("No issues", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                ForEach(document.validationState.issues) { issue in
                    Label(issue.message, systemImage: symbolName(for: issue.severity))
                        .foregroundStyle(color(for: issue.severity))
                        .font(.callout)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        // Flexible, not a hard width. A fixed frame here propagates a hard
        // minimum up into the window's split-view negotiation and stops the
        // detail column compressing, which collapses the sidebar when the
        // inspector is open.
        .frame(minWidth: 180, idealWidth: 280, maxWidth: 320, alignment: .leading)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Preview")
                .padding(.horizontal, 16)

            // Horizontally scrollable so the row never imposes a hard minimum
            // width on the detail column.
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 24) {
                    ForEach(document.previewSettings.pointSizes, id: \.self) { size in
                        VStack(spacing: 6) {
                            Text("\(Int(size)) pt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            // Placeholder until the artwork layer renders. The
                            // preview strip is deliberately present from the
                            // start so small-size feedback is never an
                            // afterthought.
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(.quaternary,
                                              style: StrokeStyle(dash: [2, 2]))
                                .frame(width: size, height: size)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 1)
            }
            .scrollIndicators(.automatic)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func symbolName(for severity: ValidationSeverity) -> String {
        switch severity {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private func color(for severity: ValidationSeverity) -> Color {
        switch severity {
        case .info: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}
