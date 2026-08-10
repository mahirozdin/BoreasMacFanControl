import Core
import Foundation
import OSLog

/// The one place in this application that opens a network connection.
///
/// `make gate-privacy` allows `URLSession` **only** under
/// `App/Sources/Automation/` and refuses it everywhere else, so the promise in
/// [ADR 0014](../../../docs/architecture/adr/0014-zero-telemetry.md) — no
/// network by default — stays a fact about the code rather than an intention.
/// Nothing here runs unless the user configured a webhook and turned automation
/// on.
struct WebhookSender {

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "automation")

    /// A session of its own rather than `URLSession.shared`: shared carries a
    /// cache and a cookie store this application has no use for, and both are
    /// state about where the user has been.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    /// Sends one request. Returns the status line for the drill and the log;
    /// a failure is reported, never thrown at the caller — an automation that
    /// took the application down with it would be worse than no automation.
    func send(
        url: String, method: String, body: String, timeout: Double
    ) async -> String {
        guard let endpoint = URL(string: url), let scheme = endpoint.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else {
            logger.error("webhook refused: not an http(s) URL")
            return "refused: not an http(s) URL"
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = method.uppercased()
        request.timeoutInterval = timeout
        if !body.isEmpty {
            request.httpBody = Data(body.utf8)
            // Only set when the user did not: their template may well be form
            // encoded, and guessing over an explicit choice is not ours to do.
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        do {
            let (_, response) = try await Self.session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.notice("webhook \(method, privacy: .public) → \(code, privacy: .public)")
            return "http \(code)"
        } catch {
            // The URL is a user's own endpoint and may contain a token, so the
            // error is logged without it (P3: no personal data in a log line).
            logger.error("webhook failed: \(error.localizedDescription, privacy: .public)")
            return "failed: \(error.localizedDescription)"
        }
    }
}
