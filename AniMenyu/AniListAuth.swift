import AppKit
import AuthenticationServices

enum AuthError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken: return "No access token in AniList callback"
        }
    }
}

@MainActor
final class AniListAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AniListAuth()

    static let clientId = "46397"
    static let callbackScheme = "animenyu"
    static let redirectURL = "\(callbackScheme)://auth"

    private var session: ASWebAuthenticationSession?

    /// Runs the AniList implicit grant flow and returns the access token.
    func signIn() async throws -> String {
        let url = URL(string: "https://anilist.co/api/v2/oauth/authorize?client_id=\(Self.clientId)&response_type=token")!
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: Self.callbackScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                // Token arrives in the URL fragment: animenyu://auth#access_token=...&token_type=Bearer
                guard let fragment = callbackURL?.fragment,
                      let token = Self.value(for: "access_token", in: fragment)
                else {
                    continuation.resume(throwing: AuthError.missingToken)
                    return
                }
                continuation.resume(returning: token)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
            self.session = session
        }
    }

    private static func value(for key: String, in fragment: String) -> String? {
        for pair in fragment.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2, parts[0] == key {
                return parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        return nil
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.windows.first { $0.isVisible } ?? ASPresentationAnchor()
        }
    }
}
