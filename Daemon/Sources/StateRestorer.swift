import Foundation
import IOKit.pwr_mgt
import OSLog

/// Hands the fans back the moment the system, not the client, is the reason
/// control must end: sleep, shutdown, or this process being told to stop.
///
/// The watchdog covers a client that falls silent; this covers the helper's
/// own world ending. Neither channel is trusted to be the only one — every
/// path lands in the same idempotent release, so arriving twice is free.
final class StateRestorer {

    private let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "restore")
    private let onRestore: @Sendable () -> Void

    private var powerConnection: io_connect_t = 0
    private var powerNotifier: IONotificationPortRef?
    private var powerNotifierObject: io_object_t = 0
    private var terminationSources: [any DispatchSourceSignal] = []

    /// These arrive from `IOMessage.h` as C macros, which Swift cannot
    /// import. The values are part of the stable IOKit message numbering.
    enum PowerMessage {
        static let canSystemSleep: UInt32 = 0xE000_0270
        static let systemWillSleep: UInt32 = 0xE000_0280
        static let systemWillPowerOff: UInt32 = 0xE000_0250
    }

    init(onRestore: @escaping @Sendable () -> Void) {
        self.onRestore = onRestore
    }

    /// Registers for sleep/shutdown notifications and termination signals.
    ///
    /// - Sleep and shutdown arrive through `IORegisterForSystemPower`.
    ///   `NSWorkspace` notifications are deliberately NOT used: they belong
    ///   to a logged in user session, and this process is a root daemon that
    ///   outlives and precedes any session.
    /// - launchd stops a daemon with SIGTERM (unregister, system teardown).
    ///   Handling it means the fans are released *before* the process dies
    ///   instead of relying on the client noticing afterwards.
    func arm(restoreAndExit: @escaping @Sendable () -> Never) {
        armPowerNotifications()
        armTerminationSignals(restoreAndExit: restoreAndExit)
    }

    private func armPowerNotifications() {
        // A C function pointer cannot capture, so the instance travels
        // through IOKit's own refcon pointer. Unretained is safe: the
        // composition root keeps this object alive for the process lifetime.
        powerConnection = IORegisterForSystemPower(
            Unmanaged.passUnretained(self).toOpaque(),
            &powerNotifier, StateRestorer.powerCallback, &powerNotifierObject)

        if powerConnection != MACH_PORT_NULL, let powerNotifier {
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                IONotificationPortGetRunLoopSource(powerNotifier).takeUnretainedValue(),
                .commonModes
            )
        } else {
            // Not fatal: the watchdog still hands the fans back. Worth
            // recording, because it means one of the layers is missing.
            logger.error(
                "could not register for system power notifications; other layers remain")
        }
    }

    private static let powerCallback: IOServiceInterestCallback = { refcon, _, messageType, argument in
        guard let refcon else { return }
        let restorer = Unmanaged<StateRestorer>.fromOpaque(refcon).takeUnretainedValue()
        switch messageType {
        case PowerMessage.systemWillSleep, PowerMessage.systemWillPowerOff:
            restorer.handleSystemGoingDown()
            // Acknowledge so the system is not held up waiting on us.
            IOAllowPowerChange(restorer.powerConnection, Int(bitPattern: argument))
        case PowerMessage.canSystemSleep:
            IOAllowPowerChange(restorer.powerConnection, Int(bitPattern: argument))
        default:
            break
        }
    }

    private func handleSystemGoingDown() {
        logger.notice("system is going down, releasing fans")
        onRestore()
    }

    private func armTerminationSignals(restoreAndExit: @escaping @Sendable () -> Never) {
        for sig in [SIGTERM, SIGINT] {
            // Default disposition would kill the process before the release
            // ran; ignoring the signal hands delivery to the dispatch source.
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [logger] in
                logger.notice("told to stop, releasing fans and exiting")
                restoreAndExit()
            }
            source.resume()
            terminationSources.append(source)
        }
    }
}
