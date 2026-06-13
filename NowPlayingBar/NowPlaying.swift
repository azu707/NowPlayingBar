import Foundation

enum NowPlaying: Equatable {
    case active(TrackInfo)
    case unavailable(UnavailableReason)
}

enum UnavailableReason: Equatable {
    case notRunning
    case permissionDenied
    case error(String)

    var message: String {
        switch self {
        case .notRunning:
            return "Open Music and start playback."
        case .permissionDenied:
            return "Allow NowPlayingBar to control Music in System Settings > Privacy & Security > Automation."
        case .error(let message):
            return message
        }
    }
}
