import Foundation

enum PlaybackState: String, Equatable {
    case playing
    case paused
    case stopped
    case notRunning
    case permissionDenied
    case error

    var displayName: String {
        switch self {
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
        case .notRunning:
            return "Music is not running"
        case .permissionDenied:
            return "Music access is not allowed"
        case .error:
            return "Unable to read Music"
        }
    }
}

struct TrackInfo: Equatable {
    var playbackState: PlaybackState
    var persistentID: String
    var name: String
    var artist: String
    var album: String
    var artworkData: Data?
    var message: String?

    static let idle = TrackInfo(
        playbackState: .notRunning,
        persistentID: "",
        name: "",
        artist: "",
        album: "",
        artworkData: nil,
        message: "Open Music and start playback."
    )

    var hasTrack: Bool {
        !name.isEmpty || !artist.isEmpty || !album.isEmpty
    }

    var menuBarTitle: String {
        guard hasTrack else {
            return ""
        }

        if artist.isEmpty {
            return name
        }

        if name.isEmpty {
            return artist
        }

        return "\(name) - \(artist)"
    }

    var detailTitle: String {
        name.isEmpty ? playbackState.displayName : name
    }

    var detailSubtitle: String {
        if artist.isEmpty && album.isEmpty {
            return message ?? playbackState.displayName
        }

        if artist.isEmpty {
            return album
        }

        if album.isEmpty {
            return artist
        }

        return "\(artist)\n\(album)"
    }
}

