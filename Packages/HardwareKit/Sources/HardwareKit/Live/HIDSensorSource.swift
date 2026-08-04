import Core
import Foundation

/// Reads temperatures from the HID sensor services.
///
/// This is the primary sensor backend because it is the only one that reports
/// **names**. The SMC exposes the same silicon as opaque four character keys
/// (`TCMz`, `Tp0D`), while these services report strings a person can read
/// (`pACC MTR Temp Sensor1`), which is what makes grouping and the interface
/// meaningful.
///
/// ## Why this is loaded dynamically
///
/// The interface is not part of any public SDK header, so the symbols cannot be
/// linked against. They are resolved at runtime instead, and **every one of
/// them is optional**: if a future macOS moves or removes the interface, this
/// type reports itself unavailable and ``LiveSensorSource`` falls back to the
/// SMC rather than the application failing.
///
/// This is the risk recorded as R1 in `docs/reference/risks.md`, and the
/// fallback is the mitigation. Using an undocumented interface is an App Store
/// review concern, not a notarisation one, and the project does not ship
/// through the App Store (ADR 0017, ADR 0018).
public struct HIDSensorSource: SensorSource {

    public let identifier = "hid"

    private let library: HIDSymbols
    private let overrides: [String: SensorOverride]

    public init(overrides: [String: SensorOverride] = [:]) throws {
        guard let library = HIDSymbols.shared else {
            throw HardwareError.serviceUnavailable("HID sensor interface not resolvable on this system")
        }
        self.library = library
        self.overrides = overrides
    }

    /// True when the interface resolved. Callers use this to decide whether to
    /// even try, without paying for a failed read.
    public static var isAvailable: Bool { HIDSymbols.shared != nil }

    public func snapshot() async throws -> [SensorReading] {
        let services = try library.temperatureServices()
        guard !services.isEmpty else {
            throw HardwareError.noData("no temperature services matched")
        }

        var readings: [SensorReading] = []
        readings.reserveCapacity(services.count)

        for service in services {
            guard
                let name = library.productName(of: service),
                let celsius = library.temperature(of: service)
            else { continue }

            let reading = SensorClassifier.makeReading(
                rawName: name,
                celsius: celsius,
                overrides: overrides
            )
            // A parked cluster reports values far outside anything physical.
            // Those are dropped rather than being handed to a fan curve.
            guard reading.isPlausible else { continue }
            readings.append(reading)
        }

        guard !readings.isEmpty else {
            throw HardwareError.noData("temperature services matched but produced no usable values")
        }
        return readings.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Dynamic symbol resolution

/// Resolves the HID sensor entry points at runtime.
///
/// Kept deliberately small and in one place: every unsafe assumption this
/// project makes about undocumented interfaces lives here, so there is exactly
/// one file to revisit when a macOS release changes something.
final class HIDSymbols: @unchecked Sendable {

    private typealias ClientCreate = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
    private typealias ClientSetMatching = @convention(c) (CFTypeRef?, CFDictionary?) -> Int32
    private typealias ClientCopyServices = @convention(c) (CFTypeRef?) -> Unmanaged<CFArray>?
    private typealias ServiceCopyProperty = @convention(c) (CFTypeRef?, CFString?) -> Unmanaged<CFTypeRef>?
    private typealias ServiceCopyEvent =
        @convention(c) (CFTypeRef?, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
    private typealias EventGetFloatValue = @convention(c) (CFTypeRef?, Int32) -> Double

    /// `kIOHIDEventTypeTemperature`
    private static let temperatureEventType: Int64 = 15

    /// Field identifiers are `type << 16`.
    private static let temperatureField: Int32 = 15 << 16

    /// `AppleSensors` publishes temperature services under this usage pair.
    private static let sensorUsagePage = 0xFF00
    private static let temperatureUsage = 0x0005

    private let handle: UnsafeMutableRawPointer
    private let clientCreate: ClientCreate
    private let clientSetMatching: ClientSetMatching
    private let clientCopyServices: ClientCopyServices
    private let serviceCopyProperty: ServiceCopyProperty
    private let serviceCopyEvent: ServiceCopyEvent
    private let eventGetFloatValue: EventGetFloatValue

    private let client: CFTypeRef

    /// Resolved once. `nil` means the interface is unavailable and the caller
    /// should fall back rather than retry.
    static let shared: HIDSymbols? = HIDSymbols()

    private init?() {
        let path = "/System/Library/Frameworks/IOKit.framework/IOKit"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }

        guard
            let create = symbol("IOHIDEventSystemClientCreate", as: ClientCreate.self),
            let setMatching = symbol("IOHIDEventSystemClientSetMatching", as: ClientSetMatching.self),
            let copyServices = symbol("IOHIDEventSystemClientCopyServices", as: ClientCopyServices.self),
            let copyProperty = symbol("IOHIDServiceClientCopyProperty", as: ServiceCopyProperty.self),
            let copyEvent = symbol("IOHIDServiceClientCopyEvent", as: ServiceCopyEvent.self),
            let floatValue = symbol("IOHIDEventGetFloatValue", as: EventGetFloatValue.self)
        else {
            dlclose(handle)
            return nil
        }

        guard let created = create(kCFAllocatorDefault)?.takeRetainedValue() else {
            dlclose(handle)
            return nil
        }

        self.handle = handle
        self.clientCreate = create
        self.clientSetMatching = setMatching
        self.clientCopyServices = copyServices
        self.serviceCopyProperty = copyProperty
        self.serviceCopyEvent = copyEvent
        self.eventGetFloatValue = floatValue
        self.client = created

        let matching: [String: Any] = [
            "PrimaryUsagePage": Self.sensorUsagePage,
            "PrimaryUsage": Self.temperatureUsage,
        ]
        _ = setMatching(client, matching as CFDictionary)
    }

    /// Every service matching the temperature usage pair.
    func temperatureServices() throws -> [CFTypeRef] {
        guard let array = clientCopyServices(client)?.takeRetainedValue() else {
            throw HardwareError.noData("IOHIDEventSystemClientCopyServices returned nothing")
        }
        guard let services = array as? [CFTypeRef] else {
            throw HardwareError.noData("service list was not an array")
        }
        return services
    }

    /// The human readable name the service publishes.
    func productName(of service: CFTypeRef) -> String? {
        guard
            let value = serviceCopyProperty(service, "Product" as CFString)?.takeRetainedValue(),
            let name = value as? String,
            !name.isEmpty
        else { return nil }
        return name
    }

    /// The current temperature in degrees Celsius.
    func temperature(of service: CFTypeRef) -> Double? {
        guard
            let event = serviceCopyEvent(service, Self.temperatureEventType, 0, 0)?.takeRetainedValue()
        else { return nil }
        let value = eventGetFloatValue(event, Self.temperatureField)
        guard value.isFinite else { return nil }
        return value
    }
}
