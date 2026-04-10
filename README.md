# NowPlayingBar

NowPlayingBar is a small macOS menu bar app that reads the current Music.app track with Apple Events and shows the track title in the menu bar.

NowPlayingBar は、Apple Events で Music.app の再生中トラックを読み取り、曲名をメニューバーに表示する小さな macOS アプリです。

Click the menu bar item to see album artwork, track details, elapsed and remaining time, playback controls, a manual refresh button, and a quit button.

メニューバー項目をクリックすると、アルバムアート、曲情報、再生済み時間と残り時間、再生操作、手動更新ボタン、終了ボタンを確認できます。

## Build

## ビルド

```sh
xcodebuild -project NowPlayingBar.xcodeproj -scheme NowPlayingBar -configuration Debug -destination 'platform=macOS,arch=arm64' build
```

The first launch may ask for permission to control Music. Allow it so NowPlayingBar can read the current track and artwork.

初回起動時に Music の制御許可を求められる場合があります。NowPlayingBar が再生中の曲とアートワークを読み取れるよう、許可してください。
