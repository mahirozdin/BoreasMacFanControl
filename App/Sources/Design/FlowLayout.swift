import SwiftUI

/// Lays subviews out in a row, wrapping to the next line when the next one
/// would not fit (P8.10).
///
/// **Why this exists.** The menu bar panel's profile picker was an `HStack` of
/// five chips inside a 320 pt panel, and they did not fit: SwiftUI resolved the
/// overflow by truncating the labels, so the shipped panel read `Balan…` and
/// `Performa…` in English and worse in the longer languages. That contradicts
/// the rule this project states absolutely in
/// `docs/development/localization.md` — *"Except for the menu bar item,
/// overflow is never solved by truncation"* — and the panel is not the menu bar
/// item, it is the window under it.
///
/// The rule's own sentence names the remedy: labels "grow with their content
/// and **wrap** when needed". Widening the panel would only move the failure to
/// the next language, since Russian runs 30–50% longer than English; a dropdown
/// would cost the one-click switching the picker exists for.
///
/// A subview wider than the whole line still cannot fit, and this layout does
/// not pretend otherwise — it gives it a line of its own and lets it be as wide
/// as it is. `--layout-drill` is what asserts that no chip ever gets there.
struct FlowLayout: Layout {

    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
    ) -> CGSize {
        let limit = proposal.width ?? .infinity
        let lines = arrange(subviews: subviews, limit: limit)
        let width = lines.map(\.width).max() ?? 0
        let height =
            lines.map(\.height).reduce(0, +)
            + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: min(width, limit == .infinity ? width : limit), height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
    ) {
        let lines = arrange(subviews: subviews, limit: bounds.width)
        var top = bounds.minY
        for line in lines {
            var leading = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: leading, y: top + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size))
                leading += size.width + spacing
            }
            top += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, limit: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && needed > limit {
                lines.append(current)
                current = Line()
            }
            current.width =
                current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}
