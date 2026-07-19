import Foundation

enum AniListError: LocalizedError {
    case http(Int)
    case graphQL(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .http(let code): return "AniList returned HTTP \(code)"
        case .graphQL(let message): return message
        case .emptyResponse: return "Empty response from AniList"
        }
    }
}

struct AniListClient {
    let token: String

    private static let endpoint = URL(string: "https://graphql.anilist.co")!

    private static let viewerQuery = """
    query { Viewer { id name } }
    """

    private static let listQuery = """
    query ($userId: Int) {
      MediaListCollection(userId: $userId, type: ANIME, status_in: [CURRENT, REPEATING]) {
        lists {
          entries {
            id
            progress
            media {
              id
              status
              siteUrl
              episodes
              title { userPreferred }
              coverImage { extraLarge large }
              nextAiringEpisode { episode airingAt }
            }
          }
        }
      }
    }
    """

    private static let saveMutation = """
    mutation ($id: Int, $progress: Int) {
      SaveMediaListEntry(id: $id, progress: $progress) { id progress }
    }
    """

    func fetchViewer() async throws -> ViewerPayload.Viewer {
        let payload: ViewerPayload = try await send(Self.viewerQuery)
        return payload.viewer
    }

    func fetchWatching(userId: Int) async throws -> [AnimeEntry] {
        let payload: ListPayload = try await send(Self.listQuery, variables: ["userId": userId])

        var seen = Set<Int>()
        var entries: [AnimeEntry] = []
        let releasing = payload.collection.lists.flatMap(\.entries).filter { $0.media.status == "RELEASING" }
        for raw in releasing where seen.insert(raw.id).inserted {
            let media = raw.media
            entries.append(AnimeEntry(
                id: raw.id,
                progress: raw.progress,
                media: Media(
                    id: media.id,
                    title: media.title.userPreferred,
                    coverURL: (media.coverImage.extraLarge ?? media.coverImage.large).flatMap(URL.init(string:)),
                    siteURL: media.siteUrl.flatMap(URL.init(string:)),
                    episodes: media.episodes,
                    nextEpisode: media.nextAiringEpisode?.episode,
                    airingAt: media.nextAiringEpisode.map { Date(timeIntervalSince1970: TimeInterval($0.airingAt)) }
                )
            ))
        }

        // Airing soonest first, then the rest alphabetically
        return entries.sorted { a, b in
            switch (a.media.airingAt, b.media.airingAt) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.media.title < b.media.title
            }
        }
    }

    func saveProgress(entryId: Int, progress: Int) async throws -> Int {
        let payload: SavePayload = try await send(Self.saveMutation, variables: ["id": entryId, "progress": progress])
        return payload.entry.progress
    }

    private func send<T: Decodable>(_ query: String, variables: [String: Any] = [:]) async throws -> T {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])

        let (data, response) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
        if let message = decoded.errors?.first?.message {
            throw AniListError.graphQL(message)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AniListError.http(http.statusCode)
        }
        guard let payload = decoded.data else { throw AniListError.emptyResponse }
        return payload
    }
}
