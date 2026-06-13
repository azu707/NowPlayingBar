import XCTest
@testable import NowPlayingBar

final class TrackInfoTests: XCTestCase {
    func testMenuBarTitleWithNameAndArtist() {
        var info = TrackInfo.idle
        info.name = "Song"
        info.artist = "Artist"

        XCTAssertEqual(info.menuBarTitle, "Song - Artist")
    }

    func testMenuBarTitleFallsBackToNameOnly() {
        var info = TrackInfo.idle
        info.name = "Song"

        XCTAssertEqual(info.menuBarTitle, "Song")
    }

    func testMenuBarTitleFallsBackToArtistOnly() {
        var info = TrackInfo.idle
        info.artist = "Artist"

        XCTAssertEqual(info.menuBarTitle, "Artist")
    }

    func testMenuBarTitleIsEmptyWithoutTrackFields() {
        let info = TrackInfo.idle

        XCTAssertEqual(info.menuBarTitle, "")
    }

    func testDetailSubtitleUsesMessageWhenArtistAndAlbumAreEmpty() {
        var info = TrackInfo.idle
        info.message = "Custom message"

        XCTAssertEqual(info.detailSubtitle, "Custom message")
    }

    func testDetailSubtitleFallsBackToAlbumOnly() {
        var info = TrackInfo.idle
        info.album = "Album"

        XCTAssertEqual(info.detailSubtitle, "Album")
    }

    func testDetailSubtitleFallsBackToArtistOnly() {
        var info = TrackInfo.idle
        info.artist = "Artist"

        XCTAssertEqual(info.detailSubtitle, "Artist")
    }

    func testDetailSubtitleCombinesArtistAndAlbum() {
        var info = TrackInfo.idle
        info.artist = "Artist"
        info.album = "Album"

        XCTAssertEqual(info.detailSubtitle, "Artist\nAlbum")
    }

    func testTimeDisplayFormatsElapsedAndRemaining() {
        var info = TrackInfo.idle
        info.elapsedTime = 83.4
        info.duration = 200

        XCTAssertEqual(info.timeDisplay, "1:23 / -1:56")
    }

    func testTimeDisplayFormatsZeroSeconds() {
        var info = TrackInfo.idle
        info.elapsedTime = 0
        info.duration = 0

        XCTAssertEqual(info.timeDisplay, "0:00 / -0:00")
    }

    func testTimeDisplayFormatsMinuteBoundary() {
        var info = TrackInfo.idle
        info.elapsedTime = 59
        info.duration = 119

        XCTAssertEqual(info.timeDisplay, "0:59 / -1:00")

        info.elapsedTime = 60
        info.duration = 120

        XCTAssertEqual(info.timeDisplay, "1:00 / -1:00")
    }

    func testTimeDisplayClampsNegativeElapsedTime() {
        var info = TrackInfo.idle
        info.elapsedTime = -1
        info.duration = -1

        XCTAssertEqual(info.timeDisplay, "0:00 / -0:00")
    }

    func testTimeDisplayIsEmptyWithoutElapsedTime() {
        var info = TrackInfo.idle
        info.elapsedTime = nil
        info.duration = 120

        XCTAssertEqual(info.timeDisplay, "")
    }

    func testTimeDisplayIsEmptyWithoutDuration() {
        var info = TrackInfo.idle
        info.elapsedTime = 20
        info.duration = nil

        XCTAssertEqual(info.timeDisplay, "")
    }

    func testRemainingTimeClampsAtZero() {
        var info = TrackInfo.idle
        info.elapsedTime = 250
        info.duration = 200

        XCTAssertEqual(info.remainingTime, 0)
        XCTAssertEqual(info.timeDisplay, "4:10 / -0:00")
    }

    func testCanControlPlaybackCases() {
        XCTAssertTrue(trackInfo(playbackState: .playing).canControlPlayback)
        XCTAssertTrue(trackInfo(playbackState: .paused).canControlPlayback)
        XCTAssertTrue(trackInfo(playbackState: .stopped).canControlPlayback)
        XCTAssertFalse(trackInfo(playbackState: .notRunning).canControlPlayback)
        XCTAssertFalse(trackInfo(playbackState: .permissionDenied).canControlPlayback)
        XCTAssertFalse(trackInfo(playbackState: .error).canControlPlayback)
    }

    private func trackInfo(playbackState: PlaybackState) -> TrackInfo {
        TrackInfo(
            playbackState: playbackState,
            persistentID: "",
            name: "",
            artist: "",
            album: "",
            artworkData: nil,
            elapsedTime: nil,
            duration: nil,
            message: nil
        )
    }
}
