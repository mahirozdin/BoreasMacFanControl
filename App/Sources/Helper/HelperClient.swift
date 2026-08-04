import Foundation
import OSLog
import SharedIPC

/// Talks to the privileged helper over XPC.
///
/// The connection carries a code signing requirement in both directions: the
/// helper refuses callers that are not us, and this refuses a helper that is
/// not ours. A one sided check would leave the application willing to take
/// orders from anything that managed to claim the Mach service name.
public actor HelperClient {

    public enum ClientError: Error, Equatable {
        case notConnected
        case rejected(String)
    }

    /// What the helper reports about one fan.
    ///
    /// A named type rather than a tuple: this crosses a privilege boundary and
    /// four unlabelled numbers are exactly the kind of thing that gets
    /// transposed in a refactor.
    public struct FanSnapshot: Sendable, Hashable {
        public let id: Int
        public let minimumRPM: Int
        public let maximumRPM: Int
        public let currentRPM: Int
    }

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "xpc")
    private var connection: NSXPCConnection?
    private var heartbeatTask: Task<Void, Never>?

    public init() {}

    /// The team this build belongs to. The helper is required to match.
    private var teamIdentifier: String? {
        guard let info = Bundle.main.infoDictionary,
            let identifier = info["CFBundleIdentifier"] as? String,
            !identifier.isEmpty
        else { return nil }
        return SigningIdentity.teamIdentifier()
    }

    private func makeConnection() throws -> NSXPCConnection {
        if let connection { return connection }

        guard let team = teamIdentifier else {
            throw ClientError.rejected("this build carries no team identifier")
        }

        let created = NSXPCConnection(
            machServiceName: BoreasIPC.machServiceName,
            options: .privileged
        )
        created.remoteObjectInterface = NSXPCInterface(with: (any FanControlProtocol).self)
        created.setCodeSigningRequirement(
            BoreasIPC.requirement(teamIdentifier: team, identifier: BoreasIPC.machServiceName)
        )
        // The handler runs on an XPC queue. Hopping back onto the actor keeps
        // the state transition where the rest of the state lives, which is what
        // Swift 6 is asking for when it complains about a sending closure.
        created.invalidationHandler = {
            Task { [weak self] in await self?.handleInvalidation() }
        }
        created.resume()
        connection = created
        return created
    }

    private func handleInvalidation() {
        logger.notice("helper connection invalidated")
        connection = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    /// Round trips a nonce. The cheapest possible proof that the connection
    /// works end to end and that the signature check on both sides passed.
    public func ping() async throws -> Bool {
        let connection = try makeConnection()
        let nonce = UInt64.random(in: 1...UInt64.max)

        return try await withCheckedThrowingContinuation { continuation in
            let proxy =
                connection.remoteObjectProxyWithErrorHandler { error in
                    continuation.resume(throwing: ClientError.rejected(String(describing: error)))
                } as? any FanControlProtocol

            guard let proxy else {
                return continuation.resume(throwing: ClientError.notConnected)
            }
            proxy.heartbeat(nonce: NSNumber(value: nonce)) { echoed in
                continuation.resume(returning: echoed.uint64Value == nonce)
            }
        }
    }

    /// Asks the helper what fans it can see. Read only.
    public func describeFans() async throws -> [FanSnapshot] {
        let connection = try makeConnection()

        return try await withCheckedThrowingContinuation { continuation in
            let proxy =
                connection.remoteObjectProxyWithErrorHandler { error in
                    continuation.resume(throwing: ClientError.rejected(String(describing: error)))
                } as? any FanControlProtocol

            guard let proxy else {
                return continuation.resume(throwing: ClientError.notConnected)
            }
            proxy.describeFans { ids, minimums, maximums, currents in
                let count = min(ids.count, minimums.count, maximums.count, currents.count)
                let fans = (0..<count).map {
                    FanSnapshot(
                        id: ids[$0].intValue,
                        minimumRPM: minimums[$0].intValue,
                        maximumRPM: maximums[$0].intValue,
                        currentRPM: currents[$0].intValue
                    )
                }
                continuation.resume(returning: fans)
            }
        }
    }

    /// Hands the fans back. Safe to call at any time.
    public func releaseToFirmware() async throws {
        let connection = try makeConnection()
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            let proxy =
                connection.remoteObjectProxyWithErrorHandler { error in
                    continuation.resume(throwing: ClientError.rejected(String(describing: error)))
                } as? any FanControlProtocol
            guard let proxy else {
                return continuation.resume(throwing: ClientError.notConnected)
            }
            proxy.releaseToFirmware { succeeded, _ in
                continuation.resume(returning: succeeded)
            }
        }
    }
}

/// Reads this process's own team identifier, the same way the helper does.
enum SigningIdentity {
    static func teamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode
        else { return nil }
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &information) == errSecSuccess,
            let dictionary = information as? [String: Any],
            let team = dictionary[kSecCodeInfoTeamIdentifier as String] as? String,
            !team.isEmpty
        else { return nil }
        return team
    }
}
