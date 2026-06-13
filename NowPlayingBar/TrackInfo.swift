import Foundation

enum PlaybackState: String, Equatable {
    case playing
    case paused
    case stopped

    var displayName: String {
        switch self {
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
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
    var elapsedTime: TimeInterval?
    var duration: TimeInterval?

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
            return playbackState.displayName
        }

        if artist.isEmpty {
            return album
        }

        if album.isEmpty {
            return artist
        }

        return "\(artist)\n\(album)"
    }

    var remainingTime: TimeInterval? {
        guard let elapsedTime, let duration else {
            return nil
        }

        return max(duration - elapsedTime, 0)
    }

    var timeDisplay: String {
        guard let elapsedTime, let remainingTime else {
            return ""
        }

        return "\(Self.formatTime(elapsedTime)) / -\(Self.formatTime(remainingTime))"
    }

    func interpolated(since fetchDate: Date, now: Date = Date()) -> TrackInfo {
        guard playbackState == .playing, let elapsedTime else {
            return self
        }

        var trackInfo = self
        let interpolatedTime = elapsedTime + now.timeIntervalSince(fetchDate)

        if let duration {
            trackInfo.elapsedTime = min(interpolatedTime, duration)
        } else {
            trackInfo.elapsedTime = interpolatedTime
        }

        return trackInfo
    }

    private static func formatTime(_ timeInterval: TimeInterval) -> String {
        let seconds = max(Int(timeInterval.rounded(.down)), 0)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}
