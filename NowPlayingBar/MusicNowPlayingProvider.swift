import AppKit
import Foundation

final class MusicNowPlayingProvider {
    fileprivate enum ReplyField: Int {
        case state = 1
        case persistentID
        case name
        case artist
        case album
        case artwork
        case elapsed
        case duration
        case message
    }

    private let musicBundleIdentifier = "com.apple.Music"
    private lazy var nowPlayingScript: NSAppleScript? = {
        let script = NSAppleScript(source: makeAppleScript())
        script?.compileAndReturnError(nil)
        return script
    }()
    private var commandScripts: [String: NSAppleScript] = [:]

    func fetchNowPlaying() -> TrackInfo {
        guard isMusicRunning else {
            return .idle
        }

        guard let script = nowPlayingScript else {
            return TrackInfo(
                playbackState: .error,
                persistentID: "",
                name: "",
                artist: "",
                album: "",
                artworkData: nil,
                message: "Could not create the Music query script."
            )
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            return trackInfo(fromAppleScriptError: errorInfo)
        }

        return trackInfo(from: descriptor)
    }

    @discardableResult
    func togglePlayPause() -> Bool {
        executeMusicCommand("playpause")
    }

    @discardableResult
    func nextTrack() -> Bool {
        executeMusicCommand("next track")
    }

    @discardableResult
    func previousTrack() -> Bool {
        executeMusicCommand("previous track")
    }

    private var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: musicBundleIdentifier).isEmpty
    }

    private func trackInfo(from descriptor: NSAppleEventDescriptor) -> TrackInfo {
        let stateText = descriptor.string(at: .state)
        let persistentID = descriptor.string(at: .persistentID)
        let name = descriptor.string(at: .name)
        let artist = descriptor.string(at: .artist)
        let album = descriptor.string(at: .album)
        let artworkData = descriptor.data(at: .artwork)
        let elapsedTime = descriptor.optionalDouble(at: .elapsed)
        let duration = descriptor.optionalDouble(at: .duration)
        let message = descriptor.string(at: .message)
        let state = PlaybackState(rawValue: stateText) ?? .error

        return TrackInfo(
            playbackState: state,
            persistentID: persistentID,
            name: name,
            artist: artist,
            album: album,
            artworkData: artworkData,
            elapsedTime: elapsedTime,
            duration: duration,
            message: message.isEmpty ? nil : message
        )
    }

    private func trackInfo(fromAppleScriptError errorInfo: NSDictionary) -> TrackInfo {
        let code = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
        let message = errorInfo[NSAppleScript.errorMessage] as? String

        if code == -1743 {
            return TrackInfo(
                playbackState: .permissionDenied,
                persistentID: "",
                name: "",
                artist: "",
                album: "",
                artworkData: nil,
                elapsedTime: nil,
                duration: nil,
                message: "Allow NowPlayingBar to control Music in System Settings > Privacy & Security > Automation."
            )
        }

        return TrackInfo(
            playbackState: .error,
            persistentID: "",
            name: "",
            artist: "",
            album: "",
            artworkData: nil,
            elapsedTime: nil,
            duration: nil,
            message: message ?? "Music returned an Apple Events error."
        )
    }

    private func executeMusicCommand(_ command: String) -> Bool {
        guard isMusicRunning else {
            return false
        }

        let script: NSAppleScript

        if let cachedScript = commandScripts[command] {
            script = cachedScript
        } else {
            let scriptSource = """
            try
                tell application id "\(musicBundleIdentifier)"
                    \(command)
                end tell
                return "ok"
            on error
                return "error"
            end try
            """

            guard let compiledScript = NSAppleScript(source: scriptSource) else {
                return false
            }

            compiledScript.compileAndReturnError(nil)
            commandScripts[command] = compiledScript
            script = compiledScript
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        return errorInfo == nil && descriptor.stringValue == "ok"
    }

    private func makeAppleScript() -> String {
        return """
        on maybeText(theValue)
            try
                if theValue is missing value then return ""
                return theValue as text
            on error
                return ""
            end try
        end maybeText

        try
            tell application id "\(musicBundleIdentifier)"
                set stateText to player state as text

                if stateText is "stopped" then
                    return {stateText, "", "", "", "", "", "", "", ""}
                end if

                set theTrack to current track
                set trackID to my maybeText(persistent ID of theTrack)
                set trackName to my maybeText(name of theTrack)
                set artistName to my maybeText(artist of theTrack)
                set albumName to my maybeText(album of theTrack)
                set artworkPayload to ""
                set elapsedTime to ""
                set trackDuration to ""

                try
                    set elapsedTime to player position
                end try

                try
                    set trackDuration to duration of theTrack
                end try

                if (count of artworks of theTrack) > 0 then
                    try
                        set artworkPayload to raw data of artwork 1 of theTrack
                    on error
                        try
                            set artworkPayload to data of artwork 1 of theTrack
                        end try
                    end try
                end if

                -- Keep this return order aligned with ReplyField in Swift.
                return {stateText, trackID, trackName, artistName, albumName, artworkPayload, elapsedTime, trackDuration, ""}
            end tell
        on error errMsg number errNum
            if errNum is -1743 then
                return {"permissionDenied", "", "", "", "", "", "", "", "Allow NowPlayingBar to control Music in System Settings > Privacy & Security > Automation."}
            end if

            return {"error", "", "", "", "", "", "", "", errMsg}
        end try
        """
    }
}

private extension NSAppleEventDescriptor {
    func string(at field: MusicNowPlayingProvider.ReplyField) -> String {
        atIndex(field.rawValue)?.stringValue ?? ""
    }

    func data(at field: MusicNowPlayingProvider.ReplyField) -> Data? {
        guard let data = atIndex(field.rawValue)?.data, !data.isEmpty else {
            return nil
        }

        return data
    }

    func optionalDouble(at field: MusicNowPlayingProvider.ReplyField) -> Double? {
        guard let descriptor = atIndex(field.rawValue) else {
            return nil
        }

        if let stringValue = descriptor.stringValue, stringValue.isEmpty {
            return nil
        }

        let value = descriptor.doubleValue
        return value.isFinite ? value : nil
    }
}
