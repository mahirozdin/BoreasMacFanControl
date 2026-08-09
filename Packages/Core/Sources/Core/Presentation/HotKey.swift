import Foundation

/// A key combination for a global shortcut (P6.10).
///
/// **A combination without a command, option or control modifier cannot be
/// constructed.** A global hotkey is registered with the window server and
/// fires wherever the user is typing, so a bare `F` would swallow the
/// letter in every application on the machine. Shift alone does not count:
/// `⇧F` is still a letter somebody is trying to type.
///
/// The rule lives in the initialiser rather than in a validation pass, for
/// the same reason `Curve` refuses to be non-monotone — a shortcut that
/// eats typing should not be representable.
public struct HotKey: Sendable, Hashable, Codable {

    public struct Modifiers: OptionSet, Sendable, Hashable, Codable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)

        /// The modifiers that make a combination safe to register globally.
        /// Shift is deliberately absent.
        public static let qualifying: Modifiers = [.command, .option, .control]
    }

    /// The hardware key code, as macOS reports it. Layout independent by
    /// design: a shortcut set on a Turkish keyboard stays on the same
    /// physical key when the layout changes.
    public let keyCode: Int

    public let modifiers: Modifiers

    /// Fails for a combination that would swallow ordinary typing.
    public init?(keyCode: Int, modifiers: Modifiers) {
        guard !modifiers.isDisjoint(with: .qualifying) else { return nil }
        guard keyCode >= 0 else { return nil }
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Decoding refuses the same combinations the initialiser does: a
    /// hand-edited configuration cannot install a shortcut the interface
    /// would not let anyone choose.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyCode = try container.decode(Int.self, forKey: .keyCode)
        let modifiers = Modifiers(rawValue: try container.decode(Int.self, forKey: .modifiers))
        guard let valid = HotKey(keyCode: keyCode, modifiers: modifiers) else {
            throw DecodingError.dataCorruptedError(
                forKey: .modifiers, in: container,
                debugDescription:
                    "a global shortcut needs a command, option or control modifier")
        }
        self = valid
    }

    /// How the combination is written, in the order macOS writes it.
    public var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    /// The printed name of a key code.
    ///
    /// Only the keys a shortcut is plausibly set to are named; anything
    /// else is reported as its code rather than guessed at, which keeps a
    /// wrong name out of the interface.
    public static func keyName(for keyCode: Int) -> String {
        if let letter = letters[keyCode] { return letter }
        if let named = namedKeys[keyCode] { return named }
        return "#\(keyCode)"
    }

    /// US layout positions, which is what the hardware codes mean. A key
    /// showing "A" here is the key in the A position, whatever the current
    /// layout prints on it — the same convention macOS itself uses when it
    /// draws a shortcut.
    private static let letters: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8",
        29: "0",
    ]

    private static let namedKeys: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
    }
}

/// The things a global shortcut can do (P6.10).
///
/// Deliberately few, and every one of them either shows something or asks
/// for *more* cooling. There is no shortcut that lowers a fan or switches
/// cooling off: a key combination pressed by accident, from inside another
/// application, should never be able to make a machine quieter and hotter
/// without anybody looking at it.
public enum HotKeyAction: String, Sendable, Hashable, CaseIterable, Codable {
    case openMainWindow
    case openSettings
    /// Full speed for a fixed spell, then back to the engine. The one
    /// action worth a global key on a fan control application: about to
    /// start something heavy, cool the machine first.
    case boost
    /// Hand the fans back to the firmware. Safe by definition — it is what
    /// every failure path already does.
    case releaseToFirmware

    /// How long `boost` lasts before the engine takes over again. Long
    /// enough to cover a compile or an export, short enough that a key
    /// pressed by mistake does not leave the fans loud all day.
    public static let boostMinutes = 5
}
