import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var store: AniListStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @AppStorage("showAllPast") private var showAllPast = false

    private static let columns = 5
    private static let spacing: CGFloat = 16
    private static let padding: CGFloat = 16
    private static let headerHeight: CGFloat = 16
    private static let headerSpacing: CGFloat = 8
    private static let hintHeight: CGFloat = 16
    private static let width: CGFloat = CGFloat(columns) * AnimeCardView.Size.regular.width
        + CGFloat(columns - 1) * spacing + 2 * padding

    private static func columnCount(for size: AnimeCardView.Size) -> Int {
        let content = width - 2 * padding
        return max(1, Int((content + spacing) / (size.width + spacing)))
    }

    private static func sectionHeight(count: Int, size: AnimeCardView.Size) -> CGFloat {
        let rows = (count + columnCount(for: size) - 1) / columnCount(for: size)
        return headerHeight + headerSpacing
            + CGFloat(rows) * size.height + CGFloat(rows - 1) * spacing
    }

    private var visiblePast: [AnimeEntry] {
        showAllPast ? store.pastEntries : store.trackedPastEntries
    }

    // Fit content exactly, up to 4 rows of regular cards
    private var gridHeight: CGFloat {
        guard !store.entries.isEmpty else { return 160 }
        let regular = AnimeCardView.Size.regular
        var height = 2 * Self.padding
        var sections = 0
        if !store.airingEntries.isEmpty {
            height += Self.sectionHeight(count: store.airingEntries.count, size: regular)
            sections += 1
        }
        if !store.pastEntries.isEmpty {
            height += visiblePast.isEmpty
                ? Self.headerHeight + Self.headerSpacing + Self.hintHeight
                : Self.sectionHeight(count: visiblePast.count, size: .compact)
            sections += 1
        }
        height += CGFloat(max(sections - 1, 0)) * Self.spacing
        if store.errorMessage != nil { height += 42 + Self.spacing }

        let maxHeight = 4 * regular.height + 3 * Self.spacing + 2 * Self.padding
            + Self.headerHeight + Self.headerSpacing
        return min(height, maxHeight)
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
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
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
            VStack(alignment: .leading, spacing: Self.spacing) {
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
                    if !store.airingEntries.isEmpty {
                        airingSection
                    }
                    if !store.pastEntries.isEmpty {
                        pastSection
                    }
                }
            }
            .padding(Self.padding)
        }
        .frame(height: gridHeight)
    }

    private func cardGrid(
        entries: [AnimeEntry],
        size: AnimeCardView.Size,
        tracking: Bool = false
    ) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(size.width), spacing: Self.spacing),
                count: Self.columnCount(for: size)
            ),
            alignment: .leading,
            spacing: Self.spacing
        ) {
            ForEach(entries) { entry in
                AnimeCardView(
                    entry: entry,
                    size: size,
                    reloadToken: store.refreshID,
                    isTracked: tracking && store.isTracked(entry),
                    onToggleTracked: tracking ? { store.toggleTracked(entry) } : nil
                ) { delta in
                    Task { await store.adjust(entry, by: delta) }
                }
            }
        }
    }

    private var airingSection: some View {
        VStack(alignment: .leading, spacing: Self.headerSpacing) {
            sectionLabel("Airing")
                .frame(height: Self.headerHeight)
            cardGrid(entries: store.airingEntries, size: .regular)
        }
    }

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: Self.headerSpacing) {
            HStack(spacing: 4) {
                sectionLabel("Continuing")
                Text("\(visiblePast.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button { showAllPast.toggle() } label: {
                    Text(showAllPast ? "Show tracked" : "Show all")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(showAllPast ? AnimeCardView.accent : Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(showAllPast
                    ? "Show only anime you track"
                    : "Show every finished anime in your list so you can track it")
            }
            .frame(height: Self.headerHeight)

            if visiblePast.isEmpty {
                Text("Nothing tracked yet — Show all, then bookmark a title.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(height: Self.hintHeight)
            } else {
                cardGrid(entries: visiblePast, size: .compact, tracking: true)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
