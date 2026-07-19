import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)

            VStack(spacing: 3) {
                Text("AniMenyu")
                    .font(.system(size: 20, weight: .bold))
                Text(version)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Your airing anime, right in the menu bar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Link(destination: URL(string: "https://github.com/lodev09/animenyu")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://github.com/lodev09")!) {
                    Label("@lodev09", systemImage: "person.fill")
                }
            }
            .font(.system(size: 12, weight: .medium))

            Text("MIT License © 2026 Jovanni Lo")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 28)
        .fixedSize()
    }
}
