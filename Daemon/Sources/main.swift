import Foundation
import OSLog
import SharedIPC
import os

/// Privileged helper entry point — the composition root.
///
/// Runs as root under launchd. It listens on one Mach service, accepts only
/// connections whose code signature matches this project's team, and exposes
/// four methods.
///
/// It reads no configuration, opens no network connection and spawns no
/// process. Those are not omissions to be filled in later — they are the
/// reason the privileged surface can be reasoned about at all.
///
/// ## Lifecycle
///
/// The launchd plist says "starts on demand, stops when idle", and this file
/// is where that promise is kept. The helper exits — always after releasing
/// the fans — when:
///
/// - the last client connection goes away (quit, crash, `kill -9`), or
/// - the watchdog expires (a client that is alive but silent), or
/// - launchd tells it to stop (SIGTERM on unregister or system teardown).
///
/// A resident root process that nobody is talking to is attack surface with
/// no purpose; exiting also makes every one of these paths observable from
/// the outside as a process lifecycle, without reading root logs.
let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "main")

/// The team the client must belong to: this binary's own team.
///
/// Read from our own signature rather than embedded at build time, so there is
/// no value that can be configured wrongly and no drift between the signing
/// settings and the requirement string.
let teamIdentifier = OwnIdentity.teamIdentifier() ?? ""

let service = FanControlService()

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {

    private let service: FanControlService
    private let onAllClientsGone: @Sendable () -> Void
    private let liveConnections = OSAllocatedUnfairLock(initialState: 0)

    init(service: FanControlService, onAllClientsGone: @escaping @Sendable () -> Void) {
        self.service = service
        self.onAllClientsGone = onAllClientsGone
    }

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
        connection.setCodeSigningRequirement(requirement)

        connection.exportedInterface = NSXPCInterface(with: (any FanControlProtocol).self)
        connection.exportedObject = service

        liveConnections.withLock { $0 += 1 }
        connection.invalidationHandler = { [weak self] in
            guard let self else { return }
            // A dropped connection is one of the ways control ends: the
            // client quit, crashed or was killed. `kill -9` lands here within
            // milliseconds — the watchdog exists for the client that is still
            // alive but silent.
            self.service.performRelease()
            let remaining = self.liveConnections.withLock { count -> Int in
                count -= 1
                return count
            }
            if remaining <= 0 { self.onAllClientsGone() }
        }

        connection.resume()
        logger.notice("accepted a verified connection")
        return true
    }
}

// Exit code 0: released and idle. Exit code 3: the hardware release failed
// after retries — `launchctl print` shows the last exit status, so this is
// readable from user space even though root logs are not.
let delegate = ListenerDelegate(
    service: service,
    onAllClientsGone: {
        logger.notice("last client gone, fans with firmware; exiting until needed again")
        exit(service.lastReleaseSucceeded ? 0 : 3)
    }
)

service.onWatchdogExpiry = {
    logger.notice("client silent past the watchdog window; exiting until needed again")
    exit(service.lastReleaseSucceeded ? 0 : 3)
}

let listener = NSXPCListener(machServiceName: BoreasIPC.machServiceName)
listener.delegate = delegate

// Sleep, shutdown and termination all end control before anything else ends
// this process. The watchdog remains the backstop, not the fallback.
let restorer = StateRestorer(onRestore: { service.performRelease() })
restorer.arm(restoreAndExit: {
    service.performRelease()
    exit(0)
})

logger.notice("helper starting")
listener.resume()
RunLoop.main.run()
