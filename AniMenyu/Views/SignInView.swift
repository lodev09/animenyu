import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var store: AniListStore
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)

                VStack(spacing: 4) {
                    Text("Welcome to AniMenyu")
                        .font(.system(size: 15, weight: .bold))
                    Text("Your airing anime, right in the menu bar.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                Button {
                    signIn()
                } label: {
                    Text(isSigningIn ? "Signing In…" : "Sign In with AniList")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSigningIn)

                Text("You'll be redirected to AniList to authorize.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
    }

    private func signIn() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                let token = try await AniListAuth.shared.signIn()
                store.signIn(token: token)
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                // user closed the window — not an error
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}
