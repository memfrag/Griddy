//
//  Copyright © 2026 Martin Johannesson. All rights reserved.
//

import SwiftUI
import GriddyGeometry
import GriddyDocument

/// The validation and preview strip along the bottom of the document window.
///
/// See spec 8.7 and 15.3.
struct BottomStrip: View {

    let document: SymbolDocument
    let state: ValidationState

    /// Selects the primitives an issue is about. An issue naming geometry the
    /// user then has to hunt for is only half a report.
    let reveal: (Set<PrimitiveID>) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            validationSection
            Divider()
            previewSection
        }
        .frame(height: 150)
        .background(.bar)
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                sectionHeader("Validation")
                if state.isRecomputing {
                    ProgressView()
                        .controlSize(.mini)
                        .help("Rechecking the geometry")
                }
            }

            if state.issues.isEmpty {
                Label(state.lastValidatedAt == nil ? "Not yet checked"
                                                   : "No issues",
                      systemImage: state.lastValidatedAt == nil
                        ? "circle.dotted" : "checkmark.circle.fill")
                    .foregroundStyle(state.lastValidatedAt == nil
                                     ? AnyShapeStyle(.secondary)
                                     : AnyShapeStyle(.green))
                    .font(.callout)
                    .lineLimit(1)
            } else {
                // Sorted so an error is never hidden below a note.
                ForEach(sortedIssues) { issue in
                    issueRow(issue)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        // Dimmed rather than blanked while the geometric tier reruns: a strip
        // that empties on every keystroke is harder to read than one that lags.
        // See spec 15.3.
        .opacity(state.isRecomputing ? 0.55 : 1)
        .animation(.easeOut(duration: 0.15), value: state.isRecomputing)
        // No minimum width, and every label truncates rather than demanding
        // room. Any hard minimum here is added to the detail column's minimum
        // width, which the window's split view must then find somewhere: with
        // the inspector open there is nothing left to take, so it squeezes the
        // sidebar below its own minimum and the rows clip off the left edge of
        // the window. The overflow scales exactly with what this strip demands.
        .frame(maxWidth: 300, alignment: .leading)
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

    @ViewBuilder
    private func issueRow(_ issue: ValidationIssue) -> some View {
        let label = Label(issue.message,
                          systemImage: symbolName(for: issue.severity))
            .foregroundStyle(color(for: issue.severity))
            .font(.callout)
            .lineLimit(2)
            .truncationMode(.tail)
            .help(issue.suggestedFix ?? issue.message)

        if issue.affectedPrimitiveIDs.isEmpty {
            label
        } else {
            Button {
                reveal(Set(issue.affectedPrimitiveIDs))
            } label: {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(issue.suggestedFix.map { "\($0) Click to select." }
                  ?? "Click to select.")
        }
    }

    /// Errors first, then warnings, then notes.
    private var sortedIssues: [ValidationIssue] {
        let rank: [ValidationSeverity: Int] = [.error: 0, .warning: 1, .info: 2]
        return state.issues.sorted {
            (rank[$0.severity] ?? 3) < (rank[$1.severity] ?? 3)
        }
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
