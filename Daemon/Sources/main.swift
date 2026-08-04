import Foundation
import IOKit.pwr_mgt
import OSLog
import SharedIPC

/// Privileged helper entry point.
///
/// Runs as root under launchd. It listens on one Mach service, accepts only
/// connections whose code signature matches this project's team, and exposes
/// four methods.
///
/// It reads no configuration, opens no network connection and spawns no
/// process. Those are not omissions to be filled in later — they are the
/// reason the privileged surface can be reasoned about at all.
let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "main")

/// The team the client must belong to: this binary's own team.
///
/// Read from our own signature rather than embedded at build time, so there is
/// no value that can be configured wrongly and no drift between the signing
/// settings and the requirement string.
let teamIdentifier = OwnIdentity.teamIdentifier() ?? ""

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {

    private let service = FanControlService()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard !teamIdentifier.isEmpty else {
            // Unsigned or ad-hoc signed. A helper that cannot identify itself
            // cannot decide who to trust, so it trusts nobody.
            logger.fault("this build carries no team identifier; refusing every connection")
            return false
        }

        let requirement = BoreasIPC.requirement(
            teamIdentifier: teamIdentifier,
            identifier: BoreasIPC.clientBundleIdentifier
        )

        // `setCodeSigningRequirement` is Apple's supported way to do this and
        // has been available since macOS 13. An earlier revision read
        // `connection.auditToken` and called `SecCodeCheckValidity` by hand;
        // that property is not exposed to Swift, and hand rolling the check
        // means owning a security decision Apple already makes correctly.
        //
        // The requirement is pinned to the TEAM, not to a certificate, so the
        // same string holds for development and release builds.
        // Returns void: the requirement is applied to the connection and the
        // system refuses any peer that does not satisfy it. There is no error
        // to inspect, which is the point — the decision is not ours to get
        // wrong.
        connection.setCodeSigningRequirement(requirement)

        connection.exportedInterface = NSXPCInterface(with: (any FanControlProtocol).self)
        connection.exportedObject = service

        connection.invalidationHandler = { [weak service] in
            // A dropped connection is one of the ways control ends. The
            // watchdog covers the rest.
            service?.performRelease()
        }

        connection.resume()
        logger.notice("accepted a verified connection")
        return true
    }

    func handleSystemShutdown() {
        service.performRelease()
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: BoreasIPC.machServiceName)
listener.delegate = delegate

// Sleep and shutdown both end control.
//
// `NSWorkspace` notifications are deliberately NOT used here: they belong to a
// logged in user session, and this process is a root daemon that outlives and
// precedes any session. `IORegisterForSystemPower` is the equivalent that
// actually reaches a daemon.
//
// Neither signal can be relied on to arrive, so the watchdog remains the
// backstop rather than the fallback.
var powerConnection: io_connect_t = 0
var powerNotifier: IONotificationPortRef?
var powerNotifierObject: io_object_t = 0

// These arrive from `IOMessage.h` as C macros, which Swift cannot import.
// The values are part of the stable IOKit message numbering.
enum PowerMessage {
    static let canSystemSleep: UInt32 = 0xE000_0270
    static let systemWillSleep: UInt32 = 0xE000_0280
    static let systemWillPowerOff: UInt32 = 0xE000_0250
}

let powerCallback: IOServiceInterestCallback = { _, _, messageType, argument in
    switch messageType {
    case PowerMessage.systemWillSleep, PowerMessage.systemWillPowerOff:
        logger.notice("system is going down, releasing fans")
        delegate.handleSystemShutdown()
        // Acknowledge so the system is not held up waiting on us.
        IOAllowPowerChange(powerConnection, Int(bitPattern: argument))
    case PowerMessage.canSystemSleep:
        IOAllowPowerChange(powerConnection, Int(bitPattern: argument))
    default:
        break
    }
}

powerConnection = IORegisterForSystemPower(nil, &powerNotifier, powerCallback, &powerNotifierObject)
if powerConnection != MACH_PORT_NULL, let powerNotifier {
    CFRunLoopAddSource(
        CFRunLoopGetMain(),
        IONotificationPortGetRunLoopSource(powerNotifier).takeUnretainedValue(),
        .commonModes
    )
} else {
    // Not fatal: the watchdog still hands the fans back. Worth recording,
    // because it means one of the two layers is missing.
    logger.error("could not register for system power notifications; watchdog is the only backstop")
}

logger.notice("helper starting")
listener.resume()
RunLoop.main.run()
