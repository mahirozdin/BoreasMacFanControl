import Core
import SwiftUI

/// The words for every diagnostic finding, cause and step (P6.11).
///
/// They live here rather than in `Core` because they are user facing text,
/// and user facing text in `Core` is invisible to both the String Catalog
/// and `make gate-i18n` — which is how two dozen of them went unlocalised
/// until the Turkish render made it obvious.
///
/// Every switch below is exhaustive over a `Core` enum, so adding a
/// finding is a compile error until somebody writes its words. That is the
/// contract that keeps this file honest.
///
/// **The honesty rule's vocabulary is checked over the String Catalog by
/// `make gate-i18n`, in every language.** Nothing here may name a fault;
/// nothing translated from here may either.
extension DiagnosticFinding {

    var text: String {
        switch self {
        case .fanResponseNoData:
            return String(
                localized: "diagnostics.finding.response.nodata",
                defaultValue:
                    """
                    The fans have not been driven long enough this session to \
                    judge how they respond.
                    """,
                comment: "Fan response check: not enough evidence yet")

        case .fanResponseTracking(let average):
            return String(
                localized: "diagnostics.finding.response.tracking",
                defaultValue: "The fans followed their targets to within \(average) rpm on average.",
                comment: "Fan response check: the fans are following their commands")

        case .fanResponseDeviating(let average, let worst):
            return String(
                localized: "diagnostics.finding.response.deviating",
                defaultValue:
                    """
                    The fans sat \(average) rpm from their target on average, \
                    and as much as \(worst) rpm away.
                    """,
                comment: "Fan response check: the fans are not following their commands closely")

        case .fanBalanceSingleFan:
            return String(
                localized: "diagnostics.finding.balance.single",
                defaultValue:
                    "This Mac has a single fan, so there is nothing to compare it against.",
                comment: "Fan balance check: does not apply on a single fan Mac")

        case .fanBalanceUnreadable:
            return String(
                localized: "diagnostics.finding.balance.unreadable",
                defaultValue: "No fan speeds were readable.",
                comment: "Fan balance check: no speeds to compare")

        case .fanBalanceTogether(let difference):
            return String(
                localized: "diagnostics.finding.balance.together",
                defaultValue: "The fans are within \(difference) rpm of each other.",
                comment: "Fan balance check: the fans run together")

        case .fanBalanceApart(let difference):
            return String(
                localized: "diagnostics.finding.balance.apart",
                defaultValue: "One fan is running \(difference) rpm faster than another.",
                comment: "Fan balance check: one fan runs much faster than another")

        case .sensorsUnreadable:
            return String(
                localized: "diagnostics.finding.sensors.unreadable",
                defaultValue: "No sensor is being read right now.",
                comment: "Sensor validity check: nothing to judge")

        case .sensorsHealthy(let count):
            return String(
                localized: "diagnostics.finding.sensors.healthy",
                defaultValue: "All \(count) sensors are reporting plausible, changing values.",
                comment: "Sensor validity check: every sensor looks normal")

        case .sensorsOutOfRange(let names):
            return String(
                localized: "diagnostics.finding.sensors.outofrange",
                defaultValue:
                    """
                    Some sensors are reporting values outside anything physical: \
                    \(names.formattedList).
                    """,
                comment: "Sensor validity check: readings outside the plausible range")

        case .sensorsStuck(let names):
            return String(
                localized: "diagnostics.finding.sensors.stuck",
                defaultValue:
                    """
                    Some sensors have not changed all session: \(names.formattedList).
                    """,
                comment: "Sensor validity check: readings that never move")

        case .sensorsOutOfRangeAndStuck(let outOfRange, let stuck):
            return String(
                localized: "diagnostics.finding.sensors.both",
                defaultValue:
                    """
                    Some sensors are reporting oddly — outside anything physical: \
                    \(outOfRange.formattedList); unchanged all session: \
                    \(stuck.formattedList).
                    """,
                comment: "Sensor validity check: both out of range and unmoving readings")

        case .thermalSessionTooShort:
            return String(
                localized: "diagnostics.finding.thermal.short",
                defaultValue: "The session is too short to say anything about thermal history.",
                comment: "Thermal history check: not enough time observed")

        case .thermalCalm(let peak):
            return String(
                localized: "diagnostics.finding.thermal.calm",
                defaultValue:
                    """
                    The system reported no thermal pressure this session. \
                    Peak temperature: \(Self.peakText(peak)).
                    """,
                comment: "Thermal history check: the system never reported pressure")

        case .thermalPressure(let serious, let critical, let peak):
            return String(
                localized: "diagnostics.finding.thermal.pressure",
                defaultValue:
                    """
                    The system reported serious pressure for \(serious) s and \
                    critical pressure for \(critical) s this session. \
                    Peak temperature: \(Self.peakText(peak)).
                    """,
                comment: "Thermal history check: the system reported pressure during the session")
        }
    }

    private static func peakText(_ peak: Double?) -> String {
        guard let peak else {
            return String(
                localized: "diagnostics.finding.thermal.nopeak", defaultValue: "not recorded",
                comment: "Stands in for a peak temperature that was never recorded")
        }
        return String(format: "%.1f °C", peak)
    }
}

extension DiagnosticCause {

    var text: String {
        switch self {
        case .dustInFanOrVents:
            return String(
                localized: "diagnostics.cause.dust",
                defaultValue: """
                    Dust in the fan or the vents, which makes a fan slower than \
                    its command
                    """,
                comment: "Possible explanation for a fan not following its command")
        case .loosenedConnection:
            return String(
                localized: "diagnostics.cause.connection",
                defaultValue: "A fan or cable that is not connected as firmly as it was",
                comment: "Possible explanation for a fan not following its command")
        case .firmwareOverriding:
            return String(
                localized: "diagnostics.cause.firmware",
                defaultValue: "The firmware overriding the requested speed for its own reasons",
                comment: "Possible explanation for a fan not following its command")
        case .hardwareFault:
            return String(
                localized: "diagnostics.cause.hardware",
                defaultValue: "Something wrong with the hardware itself",
                comment: "Possible explanation of last resort, phrased without accusing")
        case .fansCoolDifferentParts:
            return String(
                localized: "diagnostics.cause.differentparts",
                defaultValue: """
                    The fans are cooling different parts of the machine and are \
                    meant to differ
                    """,
                comment: "Possible explanation for two fans running at different speeds")
        case .obstructionOnSlowerFan:
            return String(
                localized: "diagnostics.cause.obstruction",
                defaultValue: "Dust or an obstruction on the slower fan",
                comment: "Possible explanation for two fans running at different speeds")
        case .fanNotResponding:
            return String(
                localized: "diagnostics.cause.notresponding",
                defaultValue: "A fan that is not responding to its command",
                comment: "Possible explanation for two fans running at different speeds")
        case .parkedCluster:
            return String(
                localized: "diagnostics.cause.parked",
                defaultValue: """
                    A cluster the system has parked, which reports a fixed value \
                    by design
                    """,
                comment: "Possible explanation for an unmoving sensor reading")
        case .sensorNotUnderstoodYet:
            return String(
                localized: "diagnostics.cause.unknownsensor",
                defaultValue: "A sensor this build does not understand yet",
                comment: "Possible explanation for an odd sensor reading")
        case .sensorStoppedReporting:
            return String(
                localized: "diagnostics.cause.stopped",
                defaultValue: "A sensor that has stopped reporting",
                comment: "Possible explanation for an odd sensor reading")
        case .sustainedHeavyWork:
            return String(
                localized: "diagnostics.cause.heavywork",
                defaultValue: "Sustained heavy work, which is the ordinary reason",
                comment: "Possible explanation for thermal pressure")
        case .restrictedAirflow:
            return String(
                localized: "diagnostics.cause.airflow",
                defaultValue: "Restricted airflow around the machine",
                comment: "Possible explanation for thermal pressure")
        case .quieterCurveThanWorkload:
            return String(
                localized: "diagnostics.cause.quietcurve",
                defaultValue: "A fan curve that is quieter than this workload wants",
                comment: "Possible explanation for thermal pressure")
        }
    }
}

extension DiagnosticStep {

    var text: String {
        switch self {
        case .checkVentsAreClear:
            return String(
                localized: "diagnostics.step.vents", defaultValue: "Check that the vents are clear",
                comment: "Suggested next step")
        case .watchWhetherDeviationChangesWithLoad:
            return String(
                localized: "diagnostics.step.watchload",
                defaultValue: "Watch whether the deviation changes with load or stays constant",
                comment: "Suggested next step")
        case .checkDifferencePersistsWhenIdle:
            return String(
                localized: "diagnostics.step.idle",
                defaultValue: "Check whether the difference persists when the machine is idle",
                comment: "Suggested next step")
        case .compareUnderLoad:
            return String(
                localized: "diagnostics.step.underload",
                defaultValue: "Compare with the machine under load, when parked clusters wake up",
                comment: "Suggested next step")
        case .reportUnknownSensor:
            return String(
                localized: "diagnostics.step.report",
                defaultValue: "Report the sensor with the unknown-sensor issue template",
                comment: "Suggested next step")
        case .tryProfileThatEngagesEarlier:
            return String(
                localized: "diagnostics.step.earlierprofile",
                defaultValue: "Try a profile that engages the fans earlier",
                comment: "Suggested next step")
        }
    }
}

extension [String] {
    /// Sensor names joined the way the reader's language joins a list.
    /// Hard coding ", " would be an English assumption inside a sentence
    /// that is otherwise translated.
    fileprivate var formattedList: String {
        ListFormatter.localizedString(byJoining: self)
    }
}
