import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var store: AniListStore
    @State private var isSigningIn = false

    static let blue = Color(red: 0.24, green: 0.71, blue: 0.95) // AniList blue

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)

                VStack(spacing: 4) {
                    Text("Welcome to AniMenyu")
                        .font(.system(size: 16, weight: .bold))
                    Text("Your airing anime, right in the menu bar.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                signIn()
            } label: {
                HStack(spacing: 8) {
                    if isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                            .colorScheme(.dark)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                        Text("Sign In with AniList")
                    }
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(isSigningIn)

            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 36)
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

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(SignInView.blue, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
