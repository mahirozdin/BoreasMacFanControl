import Core
import Foundation

/// Drill-only entry points on `ControlModel`.
///
/// Kept out of the model's own file for two reasons: it was pushing that file
/// past the length budget, and a hook that exists only for evidence reads better
/// beside the drills than beside the control path. Same intent as
/// `fixedForRendering` — named for what it is so nothing mistakes it for a
/// feature.
extension ControlModel {

    /// Forces the safety layer, for the P7.01 notification drill.
    ///
    /// The drill has to produce a *panic edge* on demand, and the honest
    /// alternatives are heating the machine past its panic threshold or waiting
    /// for it to happen — neither of which is a reproducible command. This sets
    /// the display state the notification model reads and **touches no
    /// hardware**: no target is sent, no helper is called.
    @MainActor
    func setLayerForDrill(_ layer: SafetyLayer?) {
        activeLayer = layer
        state = layer == nil ? .monitoring : .panic
    }
}
