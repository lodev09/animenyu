import Foundation
import SwiftUI

@MainActor
final class AniListStore: ObservableObject {
    @Published private(set) var entries: [AnimeEntry] = []
    @Published private(set) var viewerName: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var token: String?
    /// Bumped on every refresh so failed cover images retry loading.
    @Published private(set) var refreshID = 0

    @Published private(set) var trackedIDs: Set<Int> = []

    var isAuthenticated: Bool { token != nil }

    var airingEntries: [AnimeEntry] { entries.filter(\.media.isReleasing) }
    var pastEntries: [AnimeEntry] { entries.filter { !$0.media.isReleasing } }
    var trackedPastEntries: [AnimeEntry] { pastEntries.filter(isTracked) }

    private static let trackedKey = "trackedMediaIDs"

    func isTracked(_ entry: AnimeEntry) -> Bool { trackedIDs.contains(entry.media.id) }

    func toggleTracked(_ entry: AnimeEntry) {
        if trackedIDs.remove(entry.media.id) == nil {
            trackedIDs.insert(entry.media.id)
        }
        UserDefaults.standard.set(Array(trackedIDs), forKey: Self.trackedKey)
    }

    private var userId: Int?
    private var refreshTimer: Timer?

    private var client: AniListClient? {
        token.map(AniListClient.init(token:))
    }

    init() {
        token = Keychain.load()
        trackedIDs = Set(UserDefaults.standard.array(forKey: Self.trackedKey) as? [Int] ?? [])
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { _ in
            Task { @MainActor in await self.refresh() }
        }
        if isAuthenticated {
            Task { await refresh() }
        }
    }

    func signIn(token rawToken: String) {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Keychain.save(trimmed)
        token = trimmed
        userId = nil
        errorMessage = nil
        Task { await refresh() }
    }

    func signOut() {
        Keychain.delete()
        token = nil
        userId = nil
        viewerName = nil
        entries = []
        errorMessage = nil
    }

    func refresh() async {
        guard let client, !isLoading else { return }
        refreshID += 1
        isLoading = true
        defer { isLoading = false }
        do {
            if userId == nil {
                let viewer = try await client.fetchViewer()
                userId = viewer.id
                viewerName = viewer.name
            }
            entries = try await client.fetchWatching(userId: userId!)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func adjust(_ entry: AnimeEntry, by delta: Int) async {
        guard let client, let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let previous = entries[index].progress
        let target = max(0, previous + delta)
        guard target != previous else { return }
        entries[index].progress = target
        do {
            let saved = try await client.saveProgress(entryId: entry.id, progress: target)
            if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[i].progress = saved
            }
        } catch {
            if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[i].progress = previous
            }
            errorMessage = error.localizedDescription
        }
    }
}
