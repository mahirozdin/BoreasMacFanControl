import Foundation
import IOKit

/// Low level access to the System Management Controller.
///
/// The SMC exposes a flat namespace of four character keys. Each key carries a
/// type tag alongside its bytes, and the tag is what says how to decode them.
/// This type **never assumes a type**: an unrecognised tag makes the key be
/// skipped, because guessing produces a plausible number that is silently
/// wrong, and a wrong temperature drives a fan curve.
///
/// Reading is unprivileged. Writing is not, and deliberately does not exist
/// here — it belongs to the daemon.
///
/// ## Why raw bytes instead of a Swift struct
///
/// The kernel expects a specific 80 byte layout with C alignment rules. An
/// earlier revision declared it as a Swift struct and let the compiler lay it
/// out; the sizes looked right but the padding did not, and every call came
/// back `kIOReturnBadArgument`. Nothing caught it until the code met real
/// hardware, because a mock cannot disagree about struct padding.
///
/// Writing the fields at explicit offsets removes the guesswork: the layout is
/// stated once, in one place, and is checked by a test.
public final class SMCConnection: @unchecked Sendable {

    // MARK: - Wire layout

    /// Byte offsets inside the kernel's `SMCKeyData_t`.
    ///
    ///     key          0    UInt32
    ///     vers         4    6 bytes
    ///     pLimitData  10    16 bytes
    ///     keyInfo     28    dataSize UInt32, dataType UInt32, attributes UInt8
    ///     result      40    UInt8
    ///     status      41    UInt8
    ///     data8       42    UInt8
    ///     data32      44    UInt32
    ///     bytes       48    32 bytes
    ///                 80    total
    enum Offset {
        static let key = 0
        static let keyInfoDataSize = 28
        static let keyInfoDataType = 32
        static let result = 40
        static let data8 = 42
        static let data32 = 44
        static let bytes = 48
        static let total = 80
    }

    private static let kernelFunctionIndex: UInt32 = 2

    private enum Selector: UInt8 {
        case readBytes = 5
        case readKeyInfo = 9
        case readIndex = 8
    }

    // MARK: - Lifecycle

    private var connection: io_connect_t = 0
    private let lock = NSLock()

    public init() throws {
        let matching = IOServiceMatching("AppleSMC")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw HardwareError.serviceUnavailable("AppleSMC not found in the IO registry")
        }
        defer { IOObjectRelease(service) }

        var handle: io_connect_t = 0
        let status = IOServiceOpen(service, mach_task_self_, 0, &handle)
        guard status == kIOReturnSuccess else {
            throw HardwareError.serviceUnavailable("IOServiceOpen failed with \(status)")
        }
        connection = handle
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    // MARK: - Key encoding

    /// Packs a four character key into the word the SMC expects.
    public static func encode(key: String) -> UInt32 {
        var value: UInt32 = 0
        for byte in key.utf8.prefix(4) {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    public static func decode(key: UInt32) -> String {
        let bytes = [
            UInt8((key >> 24) & 0xFF),
            UInt8((key >> 16) & 0xFF),
            UInt8((key >> 8) & 0xFF),
            UInt8(key & 0xFF),
        ]
        // Non-UTF8 bytes would mean a key this build cannot name; falling back
        // to the hex form keeps it reportable instead of losing it.
        return String(bytes: bytes, encoding: .utf8)
            ?? bytes.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - Buffer helpers

    static func write(_ value: UInt32, to buffer: inout [UInt8], at offset: Int) {
        buffer[offset + 0] = UInt8(truncatingIfNeeded: value)
        buffer[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        buffer[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        buffer[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }

    static func readUInt32(_ buffer: [UInt8], at offset: Int) -> UInt32 {
        guard offset + 4 <= buffer.count else { return 0 }
        return UInt32(buffer[offset])
            | UInt32(buffer[offset + 1]) << 8
            | UInt32(buffer[offset + 2]) << 16
            | UInt32(buffer[offset + 3]) << 24
    }

    // MARK: - Transport

    private func call(_ input: [UInt8]) throws -> [UInt8] {
        precondition(input.count == Offset.total, "SMC input must be exactly \(Offset.total) bytes")

        lock.lock()
        defer { lock.unlock() }

        var output = [UInt8](repeating: 0, count: Offset.total)
        var outputSize = Offset.total

        let status = input.withUnsafeBufferPointer { inPointer in
            output.withUnsafeMutableBufferPointer { outPointer in
                IOConnectCallStructMethod(
                    connection,
                    Self.kernelFunctionIndex,
                    inPointer.baseAddress,
                    Offset.total,
                    outPointer.baseAddress,
                    &outputSize
                )
            }
        }

        guard status == kIOReturnSuccess else {
            throw HardwareError.noData(
                String(format: "IOConnectCallStructMethod returned 0x%08X", UInt32(bitPattern: status)))
        }
        let result = output[Offset.result]
        guard result == 0 else {
            throw HardwareError.noData("SMC result \(result)")
        }
        return output
    }

    private func makeRequest(key: UInt32, selector: Selector) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: Offset.total)
        Self.write(key, to: &buffer, at: Offset.key)
        buffer[Offset.data8] = selector.rawValue
        return buffer
    }

    // MARK: - Reading

    /// Number of keys the SMC currently exposes.
    public func keyCount() throws -> Int {
        guard let value = try readValue(key: "#KEY") else {
            throw HardwareError.noData("#KEY unavailable")
        }
        guard value.bytes.count >= 4 else {
            throw HardwareError.noData("#KEY was not four bytes")
        }
        // Count arrives most significant byte first.
        return Int(
            UInt32(value.bytes[0]) << 24 | UInt32(value.bytes[1]) << 16
                | UInt32(value.bytes[2]) << 8 | UInt32(value.bytes[3])
        )
    }

    /// The key at a given index, used to enumerate the namespace.
    public func key(at index: Int) throws -> String {
        var request = [UInt8](repeating: 0, count: Offset.total)
        request[Offset.data8] = Selector.readIndex.rawValue
        Self.write(UInt32(index), to: &request, at: Offset.data32)
        let response = try call(request)
        return Self.decode(key: Self.readUInt32(response, at: Offset.key))
    }

    /// Reads one key and decodes it according to the type the SMC reports.
    ///
    /// Returns `nil` for keys whose payload is empty or larger than the wire
    /// format allows. That is not an error: the namespace holds hundreds of
    /// keys, most of which are not temperatures.
    public func readValue(key: String) throws -> SMCValue? {
        let encoded = Self.encode(key: key)

        let info = try call(makeRequest(key: encoded, selector: .readKeyInfo))
        let size = Int(Self.readUInt32(info, at: Offset.keyInfoDataSize))
        let typeWord = Self.readUInt32(info, at: Offset.keyInfoDataType)
        guard size > 0, size <= 32 else { return nil }

        var request = makeRequest(key: encoded, selector: .readBytes)
        Self.write(UInt32(size), to: &request, at: Offset.keyInfoDataSize)
        Self.write(typeWord, to: &request, at: Offset.keyInfoDataType)

        let response = try call(request)
        let payload = Array(response[Offset.bytes..<(Offset.bytes + size)])

        return SMCValue(key: key, type: Self.decode(key: typeWord), bytes: payload)
    }
}

/// A decoded SMC key.
public struct SMCValue: Sendable, Hashable {
    public let key: String
    /// Four character type tag as reported by the SMC, for example `flt ` or `ui8 `.
    public let type: String
    public let bytes: [UInt8]

    public init(key: String, type: String, bytes: [UInt8]) {
        self.key = key
        self.type = type
        self.bytes = bytes
    }

    /// Interprets the bytes as a number, or returns `nil` when the type tag is
    /// one this build does not know.
    ///
    /// There is deliberately no default case that guesses. An unknown tag means
    /// the key is skipped, because a plausible wrong temperature is worse than
    /// a missing one.
    public var numericValue: Double? {
        switch type.trimmingCharacters(in: .whitespaces).trimmingCharacters(
            in: CharacterSet(charactersIn: "\0"))
        {
        case "flt":
            guard bytes.count == 4 else { return nil }
            let raw =
                UInt32(bytes[0]) | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: raw))

        case "ui8", "si8":
            guard let first = bytes.first else { return nil }
            return Double(first)

        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))

        case "ui32":
            guard bytes.count >= 4 else { return nil }
            let value =
                UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16
                | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return Double(value)

        case "sp78":
            // Signed fixed point, 7 integer bits and 8 fractional.
            guard bytes.count >= 2 else { return nil }
            let whole = Int8(bitPattern: bytes[0])
            return Double(whole) + Double(bytes[1]) / 256.0

        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0

        default:
            return nil
        }
    }
}
