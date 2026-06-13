protocol NowPlayingProviding: AnyObject, Sendable {
    func fetchNowPlaying() async -> TrackInfo
    func togglePlayPause() async
    func nextTrack() async
    func previousTrack() async
}

extension MusicNowPlayingProvider: NowPlayingProviding {}
