import SwiftUI

struct AnimeCardView: View {
    let entry: AnimeEntry
    let onAdjust: (Int) -> Void

    @State private var isHoveringBar = false
    @State private var showInfo = false

    static let accent = Color(red: 0.91, green: 0.37, blue: 0.46) // AniList pink
    static let width: CGFloat = 85
    static let height: CGFloat = 120
    static let barHeight: CGFloat = 44

    var body: some View {
        ZStack(alignment: .bottom) {
            cover
            infoBar
        }
        .frame(width: Self.width, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .animation(.easeOut(duration: 0.12), value: isHoveringBar)
        .popover(isPresented: $showInfo, arrowEdge: .trailing) {
            AnimeInfoPopover(entry: entry, onAdjust: onAdjust)
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
            default:
                Rectangle()
                    .fill(.quaternary)
            }
        }
        .frame(width: Self.width, height: Self.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { showInfo = true }
    }

    // MARK: Bottom bar

    private var infoBar: some View {
        Button(action: { onAdjust(1) }) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 3) {
                    if isHoveringBar {
                        Text("\(entry.progress) +")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else if let next = entry.media.nextEpisode, let airingAt = entry.media.airingAt {
                        Text("Ep \(next)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        CountdownText(date: airingAt)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white)
                    } else {
                        Text("Ep \(entry.progress)\(entry.media.episodes.map { " / \($0)" } ?? "")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Finished")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if entry.isBehind {
                    Rectangle()
                        .fill(Self.accent)
                        .frame(height: 4)
                }
            }
            .frame(height: Self.barHeight)
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
    let onAdjust: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.media.title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
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
            if let url = entry.media.siteURL {
                Link(destination: url) {
                    Label("Open on AniList", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                }
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
