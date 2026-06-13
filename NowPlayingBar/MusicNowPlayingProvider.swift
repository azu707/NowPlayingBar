import AppKit
import Foundation

final class MusicNowPlayingProvider: @unchecked Sendable {
    fileprivate enum ReplyField: Int {
        case state = 1
        case persistentID
        case name
        case artist
        case album
        case elapsed
        case duration
        case message
    }

    fileprivate enum ArtworkField: Int {
        case persistentID = 1
        case artwork
    }

    private let musicBundleIdentifier = "com.apple.Music"
    private let scriptQueue = DispatchQueue(label: "net.azu.NowPlayingBar.applescript")
    private lazy var statusScript: NSAppleScript? = {
        let script = NSAppleScript(source: makeStatusAppleScript())
        script?.compileAndReturnError(nil)
        return script
    }()
    private lazy var artworkScript: NSAppleScript? = {
        let script = NSAppleScript(source: makeArtworkAppleScript())
        script?.compileAndReturnError(nil)
        return script
    }()
    private var commandScripts: [String: NSAppleScript] = [:]
    private var cachedArtwork: (persistentID: String, data: Data?)?

    func fetchNowPlaying() async -> TrackInfo {
        await withCheckedContinuation { continuation in
            scriptQueue.async {
                continuation.resume(returning: self.fetchNowPlayingSync())
            }
        }
    }

    func togglePlayPause() async {
        await executeMusicCommandAsync("playpause")
    }

    func nextTrack() async {
        await executeMusicCommandAsync("next track")
    }

    func previousTrack() async {
        await executeMusicCommandAsync("previous track")
    }

    private func fetchNowPlayingSync() -> TrackInfo {
        guard isMusicRunning else {
            return .idle
        }

        guard let script = statusScript else {
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

        var trackInfo = trackInfo(from: descriptor)

        if !trackInfo.persistentID.isEmpty {
            trackInfo.artworkData = artworkData(for: trackInfo.persistentID)
        }

        return trackInfo
    }

    private func executeMusicCommandAsync(_ command: String) async {
        await withCheckedContinuation { continuation in
            scriptQueue.async {
                _ = self.executeMusicCommand(command)
                continuation.resume()
            }
        }
    }

    private var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: musicBundleIdentifier).isEmpty
    }

    private func trackInfo(from descriptor: NSAppleEventDescriptor) -> TrackInfo {
        let stateText = descriptor.string(at: .state)
        let persistentID = descriptor.string(at: ReplyField.persistentID)
        let name = descriptor.string(at: .name)
        let artist = descriptor.string(at: .artist)
        let album = descriptor.string(at: .album)
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
            artworkData: nil,
            elapsedTime: elapsedTime,
            duration: duration,
            message: message.isEmpty ? nil : message
        )
    }

    private func artworkData(for persistentID: String) -> Data? {
        if let cachedArtwork, cachedArtwork.persistentID == persistentID {
            return cachedArtwork.data
        }

        let fetched = fetchArtworkSync()

        guard fetched.persistentID == persistentID else {
            return nil
        }

        cachedArtwork = fetched
        return fetched.data
    }

    private func fetchArtworkSync() -> (persistentID: String, data: Data?) {
        guard let script = artworkScript else {
            return ("", nil)
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        guard errorInfo == nil else {
            return ("", nil)
        }

        return (
            descriptor.string(at: ArtworkField.persistentID),
            descriptor.data(at: .artwork)
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

    private func makeStatusAppleScript() -> String {
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
                    return {stateText, "", "", "", "", "", "", ""}
                end if

                set theTrack to current track
                set trackID to my maybeText(persistent ID of theTrack)
                set trackName to my maybeText(name of theTrack)
                set artistName to my maybeText(artist of theTrack)
                set albumName to my maybeText(album of theTrack)
                set elapsedTime to ""
                set trackDuration to ""

                try
                    set elapsedTime to player position
                end try

                try
                    set trackDuration to duration of theTrack
                end try

                -- Keep this return order aligned with ReplyField in Swift.
                return {stateText, trackID, trackName, artistName, albumName, elapsedTime, trackDuration, ""}
            end tell
        on error errMsg number errNum
            if errNum is -1743 then
                return {"permissionDenied", "", "", "", "", "", "", "Allow NowPlayingBar to control Music in System Settings > Privacy & Security > Automation."}
            end if

            return {"error", "", "", "", "", "", "", errMsg}
        end try
        """
    }

    private func makeArtworkAppleScript() -> String {
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
                if (player state as text) is "stopped" then
                    return {"", ""}
                end if

                set theTrack to current track
                set trackID to my maybeText(persistent ID of theTrack)
                set artworkPayload to ""

                if (count of artworks of theTrack) > 0 then
                    try
                        set artworkPayload to raw data of artwork 1 of theTrack
                    on error
                        try
                            set artworkPayload to data of artwork 1 of theTrack
                        end try
                    end try
                end if

                return {trackID, artworkPayload}
            end tell
        on error
            return {"", ""}
        end try
        """
    }
}

private extension NSAppleEventDescriptor {
    func string(at field: MusicNowPlayingProvider.ReplyField) -> String {
        atIndex(field.rawValue)?.stringValue ?? ""
    }

    func string(at field: MusicNowPlayingProvider.ArtworkField) -> String {
        atIndex(field.rawValue)?.stringValue ?? ""
    }

    func data(at field: MusicNowPlayingProvider.ArtworkField) -> Data? {
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
