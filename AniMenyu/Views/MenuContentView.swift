import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var store: AniListStore
    @Environment(\.openWindow) private var openWindow

    private static let columns = 5
    private static let spacing: CGFloat = 16
    private static let padding: CGFloat = 16
    private static let width: CGFloat = CGFloat(columns) * AnimeCardView.width
        + CGFloat(columns - 1) * spacing + 2 * padding

    // Fit content exactly, up to 4 rows of cards
    private var gridHeight: CGFloat {
        guard !store.entries.isEmpty else { return 160 }
        let rows = min(4, (store.entries.count + Self.columns - 1) / Self.columns)
        var height = CGFloat(rows) * AnimeCardView.height + CGFloat(rows - 1) * Self.spacing + 2 * Self.padding
        if store.errorMessage != nil { height += 42 }
        return height
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.isAuthenticated {
                grid
            } else {
                SignInView()
            }
        }
        .frame(width: Self.width)
        .onAppear {
            Task { await store.refresh() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("AniMenyu")
                .font(.system(size: 12, weight: .bold))
            if let name = store.viewerName {
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isLoading {
                ProgressView()
                    .controlSize(.mini)
            }
            if store.isAuthenticated {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .help("Refresh")
            }

            Menu {
                if let name = store.viewerName {
                    Section(name) {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://anilist.co/user/\(name)")!)
                        } label: {
                            Label("View Profile", systemImage: "person")
                        }
                    }
                }
                Section {
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://anilist.co/home")!)
                    } label: {
                        Label("Open AniList", systemImage: "arrow.up.right.square")
                    }
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "about")
                    } label: {
                        Label("About AniMenyu", systemImage: "info.circle")
                    }
                }
                Section {
                    if store.isAuthenticated {
                        Button(role: .destructive) {
                            store.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                    }
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Self.padding)
        .padding(.vertical, 8)
    }

    private var grid: some View {
        ScrollView {
            VStack(spacing: Self.spacing) {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                if store.entries.isEmpty && !store.isLoading {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Nothing in your watching list")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(AnimeCardView.width), spacing: Self.spacing),
                            count: Self.columns
                        ),
                        spacing: Self.spacing
                    ) {
                        ForEach(store.entries) { entry in
                            AnimeCardView(entry: entry) {
                                Task { await store.bump(entry) }
                            }
                        }
                    }
                }
            }
            .padding(Self.padding)
        }
        .frame(height: gridHeight)
    }
}
