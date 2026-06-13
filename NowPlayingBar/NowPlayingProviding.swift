protocol NowPlayingProviding: AnyObject {
    func fetchNowPlaying() -> TrackInfo
    @discardableResult func togglePlayPause() -> Bool
    @discardableResult func nextTrack() -> Bool
    @discardableResult func previousTrack() -> Bool
}

extension MusicNowPlayingProvider: NowPlayingProviding {}
