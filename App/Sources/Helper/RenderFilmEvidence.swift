import Core
import SwiftUI

/// The moving picture (P9.04). Same camera, same fixture, stepped forward.
///
/// **Why this is not an animation.** Nothing here is drawn to look like the
/// product working. Frame *n* is the main window built from the first *n*
/// samples of the very series `RenderWindowEvidence` already uses for the
/// still pictures — a series in which the temperature curve is arbitrary but
/// **the fan line is not**: it comes out of `Curve.duty(at:)` and
/// `RateLimit.standard`, the same two pieces of `Core` the running product
/// uses to decide a fan speed. So what the film shows the fans doing is what
/// the engine would do, and the lag between the two lines is the rate limiter's
/// own lag rather than a value chosen to look convincing.
///
/// That constraint is the reason this renders the *monitoring* tab. The curve
/// editor is the more flattering picture, but a film of a curve being dragged
/// would need a pointer nobody is holding, and a staged gesture is exactly the
/// thing this project does not put in its evidence.
///
/// The frames are written as numbered PNGs and encoded outside the app, by
/// `scripts/make-demo.sh`. Encoding belongs in a script: it is a maintainer
/// step whose output is committed, and no part of it should ship inside the
/// product.
extension RenderEvidence {

    /// Where the film starts in the series, how many frames it has, and how
    /// far apart they sit.
    ///
    /// Tuned against the series rather than picked: `windowSeries` puts its
    /// load spike in the last quarter (`phase - 0.72`), so a film starting at
    /// sample 640 opens on a calm machine and ends with the fan at its
    /// ceiling. Starting from zero would spend two thirds of the running time
    /// on a flat line.
    private static var filmStart: Int { 640 }
    private static var filmFrames: Int { 45 }
    private static var filmStride: Int { 12 }

    static func film(into directory: URL) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        for frame in 0..<filmFrames {
            let samples = filmStart + frame * filmStride
            let fixture = windowFixture(samples: samples)
            let view =
                MonitoringContent(
                    model: fixture.monitor,
                    control: fixture.control,
                    now: windowNow(samples: samples)
                )
                .frame(width: 860)
                .background(Color(white: 0.98))
                .environment(\.colorScheme, .light)

            // Zero padded: the encoder takes the frames in shell glob order,
            // and `frame-10` sorts before `frame-2`.
            write(view, to: directory, named: String(format: "frame-%03d", frame))
        }

        report("wrote \(filmFrames) frames covering \(filmFrames * filmStride) samples")
        report("encode them with scripts/make-demo.sh")
    }
}
