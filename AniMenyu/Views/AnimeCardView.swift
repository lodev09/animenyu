import SwiftUI

struct AnimeCardView: View {
    enum Size {
        case regular, compact

        var width: CGFloat { self == .regular ? 85 : 68 }
        var height: CGFloat { self == .regular ? 120 : 96 }
        var barHeight: CGFloat { self == .regular ? 44 : 34 }
        var primaryFontSize: CGFloat { self == .regular ? 11 : 10 }
        var secondaryFontSize: CGFloat { self == .regular ? 10.5 : 9.5 }
        var behindBarHeight: CGFloat { self == .regular ? 4 : 3 }
    }

    let entry: AnimeEntry
    var size: Size = .regular
    var reloadToken = 0
    var isTracked = false
    var onToggleTracked: (() -> Void)?
    @Binding var links: [CustomLink]
    let onAdjust: (Int) -> Void

    @State private var isHoveringBar = false
    @State private var isHoveringCard = false
    @State private var showInfo = false
    @State private var coverFailed = false

    static let accent = Color(red: 0.91, green: 0.37, blue: 0.46) // AniList pink

    var body: some View {
        ZStack(alignment: .bottom) {
            cover
            infoBar
        }
        .overlay(alignment: .topTrailing) {
            if onToggleTracked != nil, isTracked || isHoveringCard {
                trackBadge
                    .padding(4)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .onHover { isHoveringCard = $0 }
        .animation(.easeOut(duration: 0.12), value: isHoveringBar)
        .animation(.easeOut(duration: 0.12), value: isHoveringCard)
        .popover(isPresented: $showInfo, arrowEdge: .trailing) {
            AnimeInfoPopover(entry: entry, links: $links, onAdjust: onAdjust)
        }
    }

    // MARK: Cover

    private var cover: some View {
        AsyncImage(url: entry.media.coverURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .onAppear { coverFailed = false }
            case .failure:
                Rectangle()
                    .fill(.quaternary)
                    .onAppear { coverFailed = true }
            default:
                Rectangle()
                    .fill(.quaternary)
            }
        }
        // Recreate the AsyncImage on refresh only if the last load failed
        .id(coverFailed ? reloadToken : -1)
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { showInfo = true }
    }

    // MARK: Track badge

    private var trackBadge: some View {
        Button { onToggleTracked?() } label: {
            Image(systemName: isTracked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isTracked ? Self.accent : .white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(.black.opacity(0.55)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isTracked ? "Stop tracking" : "Track this anime")
    }

    // MARK: Bottom bar

    private var infoBar: some View {
        Button(action: { onAdjust(1) }) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 3) {
                    if isHoveringBar {
                        Text("\(entry.progress) +")
                            .font(.system(size: size.primaryFontSize + 1, weight: .bold))
                            .foregroundStyle(.white)
                    } else if let next = entry.media.nextEpisode, let airingAt = entry.media.airingAt {
                        Text("Ep \(next)")
                            .font(.system(size: size.primaryFontSize, weight: .semibold))
                            .foregroundStyle(.white)
                        CountdownText(date: airingAt)
                            .font(.system(size: size.secondaryFontSize))
                            .foregroundStyle(.white)
                    } else {
                        Text("Ep \(entry.progress)\(entry.media.episodes.map { " / \($0)" } ?? "")")
                            .font(.system(size: size.primaryFontSize, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Finished")
                            .font(.system(size: size.secondaryFontSize))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if entry.isBehind {
                    Rectangle()
                        .fill(Self.accent)
                        .frame(height: size.behindBarHeight)
                }
            }
            .frame(height: size.barHeight)
            .background(.black.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHoveringBar = $0 }
        .help("Mark episode \(entry.progress + 1) as watched")
    }

}

// MARK: - Info popover

struct AnimeInfoPopover: View {
    let entry: AnimeEntry
    @Binding var links: [CustomLink]
    let onAdjust: (Int) -> Void

    @State private var showMoreInfo = false
    @State private var linkEdit: LinkEdit?

    private enum LinkEdit: Equatable {
        case add
        case edit(CustomLink.ID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.isBehind {
                Text("\(entry.episodesBehind) episode\(entry.episodesBehind == 1 ? "" : "s") behind")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnimeCardView.accent)
            }
            Text(entry.media.title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: 10) {
                Text(progressText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                StepButton(systemImage: "minus", color: AnimeCardView.accent) { onAdjust(-1) }
                    .disabled(entry.progress == 0)
                    .help("Undo watched episode")
                StepButton(systemImage: "plus", color: .blue) { onAdjust(1) }
                    .help("Mark episode \(entry.progress + 1) as watched")
            }
            linksSection
            HStack {
                moreInfoToggle
                Spacer()
                if linkEdit == nil {
                    addLinkButton
                }
            }
            if showMoreInfo {
                moreInfoSection
            }
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
    }

    private var progressText: String {
        if let total = entry.media.episodes {
            return "Progress: \(entry.progress)/\(total)"
        }
        return "Progress: \(entry.progress)"
    }

    // MARK: Links

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let url = entry.media.siteURL {
                Link(destination: url) {
                    Label("Open on AniList", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            ForEach(links) { link in
                if linkEdit == .edit(link.id) {
                    CustomLinkEditor(link: link, onSave: saveLink, onDelete: { deleteLink(link) }) {
                        linkEdit = nil
                    }
                } else {
                    CustomLinkRow(link: link) { linkEdit = .edit(link.id) }
                }
            }
            if linkEdit == .add {
                CustomLinkEditor(link: nil, onSave: saveLink) { linkEdit = nil }
            }
        }
    }

    private var addLinkButton: some View {
        Button { linkEdit = .add } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                Text("Add Link")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add a custom link, like a streaming or download site")
    }

    private func saveLink(_ link: CustomLink) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links[index] = link
        } else {
            links.append(link)
        }
        linkEdit = nil
    }

    private func deleteLink(_ link: CustomLink) {
        links.removeAll { $0.id == link.id }
        linkEdit = nil
    }

    // MARK: More info

    private var moreInfoToggle: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { showMoreInfo.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text("More Info")
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(showMoreInfo ? 90 : 0))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var moreInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            InfoDetailRow(label: "Average Score", values: entry.media.averageScore.map { ["\($0)%"] } ?? [])
            InfoDetailRow(label: "Synonyms", values: entry.media.synonyms)
        }
    }
}

/// Labeled row in the More Info section. Values are selectable/copyable.
private struct InfoDetailRow: View {
    let label: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            if values.isEmpty {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text(values.joined(separator: "\n"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct CustomLinkRow: View {
    let link: CustomLink
    let onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Link(destination: link.url) {
                Label(link.displayName, systemImage: "link")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .help(link.url.absoluteString)
            Spacer(minLength: 0)
            if isHovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Edit link")
            }
        }
        .onHover { isHovering = $0 }
    }
}

private struct CustomLinkEditor: View {
    let link: CustomLink?
    let onSave: (CustomLink) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var urlText: String
    @State private var name: String
    @FocusState private var isURLFocused: Bool

    init(
        link: CustomLink?,
        onSave: @escaping (CustomLink) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.link = link
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _urlText = State(initialValue: link?.url.absoluteString ?? "")
        _name = State(initialValue: link?.name ?? "")
    }

    private var url: URL? { CustomLink.url(from: urlText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("https://…", text: $urlText)
                .focused($isURLFocused)
            TextField("Name (optional)", text: $name)
            HStack(spacing: 6) {
                if let onDelete {
                    Button("Delete", role: .destructive, action: onDelete)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: save)
                    .disabled(url == nil)
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 11))
        .controlSize(.small)
        .onSubmit(save)
        .onAppear { isURLFocused = true }
    }

    private func save() {
        guard let url else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(CustomLink(id: link?.id ?? UUID(), name: trimmedName, url: url))
    }
}

private struct StepButton: View {
    let systemImage: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isHovering ? .white : Color.secondary)
                .frame(width: 18, height: 18)
                .background {
                    ZStack {
                        Circle().fill(.quaternary.opacity(0.6))
                        Circle().fill(color).opacity(isHovering ? 1 : 0)
                    }
                }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { isHovering = $0 && isEnabled }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

/// Live "5d 17h 23m" countdown, ticking every minute.
struct CountdownText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(Self.format(until: date, now: context.date))
        }
    }

    static func format(until date: Date, now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "Aired" }
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1))m"
    }
}
