# NowPlayingBar

NowPlayingBar is a small macOS menu bar app that reads the current Music.app track with Apple Events and shows the track title in the menu bar.

Click the menu bar item to see album artwork, track details, a manual refresh button, and a quit button.

## Build

```sh
xcodebuild -project NowPlayingBar.xcodeproj -scheme NowPlayingBar -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

The first launch may ask for permission to control Music. Allow it so NowPlayingBar can read the current track and artwork.
