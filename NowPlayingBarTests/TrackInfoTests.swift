import XCTest
@testable import NowPlayingBar

final class TrackInfoTests: XCTestCase {
    func testMenuBarTitleWithNameAndArtist() {
        var info = trackInfo()
        info.name = "Song"
        info.artist = "Artist"

        XCTAssertEqual(info.menuBarTitle, "Song - Artist")
    }

    func testMenuBarTitleFallsBackToNameOnly() {
        var info = trackInfo()
        info.name = "Song"

        XCTAssertEqual(info.menuBarTitle, "Song")
    }

    func testMenuBarTitleFallsBackToArtistOnly() {
        var info = trackInfo()
        info.artist = "Artist"

        XCTAssertEqual(info.menuBarTitle, "Artist")
    }

    func testMenuBarTitleIsEmptyWithoutTrackFields() {
        let info = trackInfo()

        XCTAssertEqual(info.menuBarTitle, "")
    }

    func testDetailSubtitleUsesPlaybackStateWhenArtistAndAlbumAreEmpty() {
        let info = trackInfo(playbackState: .paused)

        XCTAssertEqual(info.detailSubtitle, "Paused")
    }

    func testDetailSubtitleFallsBackToAlbumOnly() {
        var info = trackInfo()
        info.album = "Album"

        XCTAssertEqual(info.detailSubtitle, "Album")
    }

    func testDetailSubtitleFallsBackToArtistOnly() {
        var info = trackInfo()
        info.artist = "Artist"

        XCTAssertEqual(info.detailSubtitle, "Artist")
    }

    func testDetailSubtitleCombinesArtistAndAlbum() {
        var info = trackInfo()
        info.artist = "Artist"
        info.album = "Album"

        XCTAssertEqual(info.detailSubtitle, "Artist\nAlbum")
    }

    func testTimeDisplayFormatsElapsedAndRemaining() {
        var info = trackInfo()
        info.elapsedTime = 83.4
        info.duration = 200

        XCTAssertEqual(info.timeDisplay, "1:23 / -1:56")
    }

    func testTimeDisplayFormatsZeroSeconds() {
        var info = trackInfo()
        info.elapsedTime = 0
        info.duration = 0

        XCTAssertEqual(info.timeDisplay, "0:00 / -0:00")
    }

    func testTimeDisplayFormatsMinuteBoundary() {
        var info = trackInfo()
        info.elapsedTime = 59
        info.duration = 119

        XCTAssertEqual(info.timeDisplay, "0:59 / -1:00")

        info.elapsedTime = 60
        info.duration = 120

        XCTAssertEqual(info.timeDisplay, "1:00 / -1:00")
    }

    func testTimeDisplayClampsNegativeElapsedTime() {
        var info = trackInfo()
        info.elapsedTime = -1
        info.duration = -1

        XCTAssertEqual(info.timeDisplay, "0:00 / -0:00")
    }

    func testTimeDisplayIsEmptyWithoutElapsedTime() {
        var info = trackInfo()
        info.elapsedTime = nil
        info.duration = 120

        XCTAssertEqual(info.timeDisplay, "")
    }

    func testTimeDisplayIsEmptyWithoutDuration() {
        var info = trackInfo()
        info.elapsedTime = 20
        info.duration = nil

        XCTAssertEqual(info.timeDisplay, "")
    }

    func testRemainingTimeClampsAtZero() {
        var info = trackInfo()
        info.elapsedTime = 250
        info.duration = 200

        XCTAssertEqual(info.remainingTime, 0)
        XCTAssertEqual(info.timeDisplay, "4:10 / -0:00")
    }

    func testPlaybackStateDisplayNames() {
        XCTAssertEqual(PlaybackState.playing.displayName, "Playing")
        XCTAssertEqual(PlaybackState.paused.displayName, "Paused")
        XCTAssertEqual(PlaybackState.stopped.displayName, "Stopped")
    }

    func testUnavailableReasonMessages() {
        XCTAssertEqual(UnavailableReason.notRunning.message, "Open Music and start playback.")
        XCTAssertEqual(
            UnavailableReason.permissionDenied.message,
            "Allow NowPlayingBar to control Music in System Settings > Privacy & Security > Automation."
        )
        XCTAssertEqual(UnavailableReason.error("Custom error").message, "Custom error")
    }

    private func trackInfo(playbackState: PlaybackState = .playing) -> TrackInfo {
        TrackInfo(
            playbackState: playbackState,
            persistentID: "",
            name: "",
            artist: "",
            album: "",
            artworkData: nil,
            elapsedTime: nil,
            duration: nil
        )
    }
}
