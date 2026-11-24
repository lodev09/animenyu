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
    /// Keyed by media ID.
    @Published private(set) var customLinks: [Int: [CustomLink]] = [:]

    var isAuthenticated: Bool { token != nil }

    var airingEntries: [AnimeEntry] { entries.filter(\.media.isReleasing) }
    var pastEntries: [AnimeEntry] { entries.filter { !$0.media.isReleasing } }
    var trackedPastEntries: [AnimeEntry] { pastEntries.filter(isTracked) }

    private static let trackedKey = "trackedMediaIDs"
    private static let customLinksKey = "customLinks"

    func isTracked(_ entry: AnimeEntry) -> Bool { trackedIDs.contains(entry.media.id) }

    func toggleTracked(_ entry: AnimeEntry) {
        if trackedIDs.remove(entry.media.id) == nil {
            trackedIDs.insert(entry.media.id)
        }
        UserDefaults.standard.set(Array(trackedIDs), forKey: Self.trackedKey)
    }

    func links(for entry: AnimeEntry) -> [CustomLink] { customLinks[entry.media.id] ?? [] }

    func setLinks(_ links: [CustomLink], for entry: AnimeEntry) {
        customLinks[entry.media.id] = links.isEmpty ? nil : links
        UserDefaults.standard.set(try? JSONEncoder().encode(customLinks), forKey: Self.customLinksKey)
    }

    private var userId: Int?
    private var refreshTimer: Timer?

    private static let saveDebounce: Duration = .milliseconds(600)
    /// Keyed by entry ID.
    private var pendingSaves: [Int: Task<Void, Never>] = [:]
    /// Last server-confirmed progress for entries with unsaved steps, keyed by entry ID.
    private var confirmedProgress: [Int: Int] = [:]

    private var client: AniListClient? {
        token.map(AniListClient.init(token:))
    }

    init() {
        token = Keychain.load()
        trackedIDs = Set(UserDefaults.standard.array(forKey: Self.trackedKey) as? [Int] ?? [])
        customLinks = UserDefaults.standard.data(forKey: Self.customLinksKey)
            .flatMap { try? JSONDecoder().decode([Int: [CustomLink]].self, from: $0) } ?? [:]
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

    func adjust(_ entry: AnimeEntry, by delta: Int) {
        guard let client, let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let current = entries[index].progress
        let target = max(0, current + delta)
        guard target != current else { return }
        if confirmedProgress[entry.id] == nil {
            confirmedProgress[entry.id] = current
        }
        entries[index].progress = target

        pendingSaves[entry.id]?.cancel()
        pendingSaves[entry.id] = Task {
            try? await Task.sleep(for: Self.saveDebounce)
            guard !Task.isCancelled else { return }
            pendingSaves[entry.id] = nil

            let result: Result<Int, Error>
            do {
                result = .success(try await client.saveProgress(entryId: entry.id, progress: target))
            } catch {
                result = .failure(error)
            }

            // A newer step was queued while saving; let it settle the final value.
            if pendingSaves[entry.id] != nil {
                if case .success(let saved) = result { confirmedProgress[entry.id] = saved }
                return
            }

            let fallback = confirmedProgress.removeValue(forKey: entry.id)
            guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
            switch result {
            case .success(let saved):
                entries[i].progress = saved
            case .failure(let error):
                if let fallback { entries[i].progress = fallback }
                errorMessage = error.localizedDescription
            }
        }
    }
}
