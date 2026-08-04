import Foundation
import Security

/// Reads this process's own code signing identity.
///
/// The helper requires a connecting client to carry **the same team identifier
/// as itself**. Deriving that at runtime rather than embedding it at build time
/// removes a whole class of misconfiguration: there is no value to substitute,
/// nothing to keep in step with the signing settings, and no way for a build to
/// ship a requirement that names the wrong team.
///
/// It also means the same binary is correct under an Apple Development
/// signature and under a Developer ID signature, because both carry the team
/// identifier and the check is relative rather than absolute.
enum OwnIdentity {

    /// The team identifier this binary was signed with, or nil when it is
    /// unsigned or ad-hoc signed.
    ///
    /// A nil result is treated as fatal by the caller: a helper that cannot
    /// identify itself cannot decide who to trust, and refusing every
    /// connection is the only safe response.
    static func teamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
            let staticCode
        else { return nil }

        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &information) == errSecSuccess,
            let dictionary = information as? [String: Any]
        else { return nil }

        guard let team = dictionary[kSecCodeInfoTeamIdentifier as String] as? String,
            !team.isEmpty
        else { return nil }

        return team
    }
}
