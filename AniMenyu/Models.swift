import Foundation

struct AnimeEntry: Identifiable, Equatable {
    let id: Int
    var progress: Int
    let media: Media

    /// Episodes released so far (nil if unknown).
    var airedEpisodes: Int? {
        if let next = media.nextEpisode { return next - 1 }
        return media.episodes
    }

    var isBehind: Bool {
        guard let aired = airedEpisodes else { return false }
        return progress < aired
    }
}

struct Media: Equatable {
    let id: Int
    let title: String
    let coverURL: URL?
    let siteURL: URL?
    let episodes: Int?
    let nextEpisode: Int?
    let airingAt: Date?
}

// MARK: - GraphQL payloads

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
}

struct ViewerPayload: Decodable {
    let viewer: Viewer

    enum CodingKeys: String, CodingKey { case viewer = "Viewer" }

    struct Viewer: Decodable {
        let id: Int
        let name: String
    }
}

struct ListPayload: Decodable {
    let collection: Collection

    enum CodingKeys: String, CodingKey { case collection = "MediaListCollection" }

    struct Collection: Decodable {
        let lists: [List]
    }

    struct List: Decodable {
        let entries: [Entry]
    }

    struct Entry: Decodable {
        let id: Int
        let progress: Int
        let media: RawMedia
    }

    struct RawMedia: Decodable {
        let id: Int
        let status: String?
        let title: Title
        let coverImage: Cover
        let siteUrl: String?
        let episodes: Int?
        let nextAiringEpisode: Airing?
    }

    struct Title: Decodable { let userPreferred: String }
    struct Cover: Decodable { let extraLarge: String?; let large: String? }
    struct Airing: Decodable { let episode: Int; let airingAt: Int }
}

struct SavePayload: Decodable {
    let entry: Saved

    enum CodingKeys: String, CodingKey { case entry = "SaveMediaListEntry" }

    struct Saved: Decodable {
        let id: Int
        let progress: Int
    }
}
