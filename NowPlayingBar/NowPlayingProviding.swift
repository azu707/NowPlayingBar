protocol NowPlayingProviding: AnyObject, Sendable {
    func fetchNowPlaying() async -> NowPlaying
    func togglePlayPause() async
    func nextTrack() async
    func previousTrack() async
    func setPlayerPosition(_ seconds: Double) async
}

extension MusicNowPlayingProvider: NowPlayingProviding {}
