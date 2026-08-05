import Foundation
import Testing

@testable import Core

@Suite("Status item visibility (1D concealment decision)")
struct StatusItemVisibilityTests {

    private let bar = StatusItemVisibility.Span(start: 0, width: 1512)
    private let notch = StatusItemVisibility.Span(start: 656, width: 200)

    @Test("an item fully on the bar and clear of the notch is visible")
    func visibleItem() {
        let item = StatusItemVisibility.Span(start: 1300, width: 80)
        #expect(StatusItemVisibility.assess(item: item, bar: bar, notch: notch) == .visible)
    }

    @Test("no measurable frame means crowded out, not an error")
    func missingFrameIsOffBar() {
        #expect(StatusItemVisibility.assess(item: nil, bar: bar) == .offBar)
        let empty = StatusItemVisibility.Span(start: 100, width: 0)
        #expect(StatusItemVisibility.assess(item: empty, bar: bar) == .offBar)
    }

    @Test("an item pushed past either edge of the bar is concealed")
    func pushedOffEitherEdge() {
        let right = StatusItemVisibility.Span(start: 1490, width: 80)
        #expect(StatusItemVisibility.assess(item: right, bar: bar) == .offBar)
        let left = StatusItemVisibility.Span(start: -40, width: 80)
        #expect(StatusItemVisibility.assess(item: left, bar: bar) == .offBar)
    }

    @Test("an item under the notch is concealed and the reason names the notch")
    func behindNotch() {
        let item = StatusItemVisibility.Span(start: 700, width: 80)
        #expect(StatusItemVisibility.assess(item: item, bar: bar, notch: notch) == .behindNotch)
    }

    @Test("a sliver inside the tolerance does not count as visible")
    func sliverCounts() {
        // 80 points wide, all but 1.5 of them past the bar's end: the user
        // sees a 1.5-point line. The tolerance rule calls it concealed.
        let sliver = StatusItemVisibility.Span(start: 1508.5, width: 80)
        #expect(StatusItemVisibility.assess(item: sliver, bar: bar) == .offBar)
        // Grazing the notch by less than the tolerance stays visible — a
        // 1-point kiss is not "behind the notch".
        let graze = StatusItemVisibility.Span(start: 855, width: 80)
        #expect(StatusItemVisibility.assess(item: graze, bar: bar, notch: notch) == .visible)
    }

    @Test("a machine without a notch never reports behindNotch")
    func noNotch() {
        let centre = StatusItemVisibility.Span(start: 700, width: 80)
        #expect(StatusItemVisibility.assess(item: centre, bar: bar, notch: nil) == .visible)
    }

    @Test("a negative measured width normalises to empty")
    func negativeWidth() {
        let broken = StatusItemVisibility.Span(start: 500, width: -20)
        #expect(broken.width == 0)
        #expect(StatusItemVisibility.assess(item: broken, bar: bar) == .offBar)
    }
}
