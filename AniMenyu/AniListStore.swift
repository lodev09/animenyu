import Foundation
import SwiftUI

@MainActor
final class AniListStore: ObservableObject {
    @Published private(set) var entries: [AnimeEntry] = []
    @Published private(set) var viewerName: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var token: String?

    var isAuthenticated: Bool { token != nil }

    private var userId: Int?
    private var refreshTimer: Timer?

    private var client: AniListClient? {
        token.map(AniListClient.init(token:))
    }

    init() {
        token = Keychain.load()
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

    func bump(_ entry: AnimeEntry) async {
        guard let client, let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let previous = entries[index].progress
        entries[index].progress = previous + 1
        do {
            let saved = try await client.saveProgress(entryId: entry.id, progress: previous + 1)
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
