import Foundation

/// Decides whether the menu bar status item can actually be seen.
///
/// The question is one dimensional: the menu bar is a horizontal band, the
/// item occupies a span of it, and a notch (where present) carves a dead
/// span out of the middle. Modelling it as plain numbers keeps the decision
/// in `Core` under unit tests — the App layer only measures the frames; it
/// never judges them.
public enum StatusItemVisibility {

    /// A horizontal extent in menu bar coordinates.
    public struct Span: Sendable, Hashable {
        public let start: Double
        public let width: Double

        public var end: Double { start + width }

        public init(start: Double, width: Double) {
            self.start = start
            // A negative width is a measurement artefact, not a location —
            // normalise to empty rather than letting `end` run backwards.
            self.width = Swift.max(0, width)
        }
    }

    /// Why the item cannot be seen — the warning text names the cause.
    public enum Concealment: Sendable, Hashable {
        case visible
        /// Pushed off the bar (or never given a place at all): macOS gives
        /// crowded-out items no usable frame.
        case offBar
        /// Laid out under the notch's dead span.
        case behindNotch
    }

    /// How many points of an item may poke outside before it counts as
    /// concealed. An item showing a 2-point sliver is unusable; treating it
    /// as "visible" would silence the warning exactly when it is needed.
    public static let tolerance: Double = 2

    /// Judges an item span against the bar and the notch dead span.
    ///
    /// `item` is `nil` when the item has no window or no screen — which is
    /// how a fully crowded-out item presents itself, and is concealment,
    /// not an error.
    public static func assess(
        item: Span?,
        bar: Span,
        notch: Span? = nil
    ) -> Concealment {
        guard let item, item.width > 0 else { return .offBar }

        if item.start < bar.start - tolerance || item.end > bar.end + tolerance {
            return .offBar
        }

        if let notch {
            let overlap =
                Swift.min(item.end, notch.end) - Swift.max(item.start, notch.start)
            if overlap > tolerance {
                return .behindNotch
            }
        }

        return .visible
    }
}
