import AppKit

@MainActor
final class NowPlayingPopoverViewController: NSViewController {
    var onRefresh: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onQuit: (() -> Void)?

    private let artworkImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let stateLabel = NSTextField(labelWithString: "")
    private let previousButton = NSButton(title: "", target: nil, action: nil)
    private let playPauseButton = NSButton(title: "", target: nil, action: nil)
    private let nextButton = NSButton(title: "", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configureSubviews()
        buildLayout()
        update(with: .idle)
    }

    func update(with trackInfo: TrackInfo) {
        titleLabel.stringValue = trackInfo.detailTitle
        subtitleLabel.stringValue = trackInfo.detailSubtitle
        timeLabel.stringValue = trackInfo.timeDisplay
        stateLabel.stringValue = trackInfo.message ?? trackInfo.playbackState.displayName
        updatePlaybackButtons(with: trackInfo)

        if let artworkData = trackInfo.artworkData, let image = NSImage(data: artworkData) {
            artworkImageView.image = image
        } else {
            artworkImageView.image = NSImage(
                systemSymbolName: "music.note",
                accessibilityDescription: "No artwork"
            )
        }
    }

    private func configureSubviews() {
        artworkImageView.imageAlignment = .alignCenter
        artworkImageView.imageScaling = .scaleProportionallyUpOrDown
        artworkImageView.wantsLayer = true
        artworkImageView.layer?.cornerRadius = 8
        artworkImageView.layer?.masksToBounds = true
        artworkImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.alignment = .center
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.textColor = .secondaryLabelColor

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timeLabel.alignment = .center
        timeLabel.lineBreakMode = .byTruncatingTail
        timeLabel.textColor = .secondaryLabelColor

        stateLabel.font = .systemFont(ofSize: 12)
        stateLabel.alignment = .center
        stateLabel.lineBreakMode = .byTruncatingTail
        stateLabel.maximumNumberOfLines = 2
        stateLabel.textColor = .tertiaryLabelColor

        configureIconButton(previousButton, systemSymbolName: "backward.fill", action: #selector(previousButtonClicked(_:)))
        configureIconButton(playPauseButton, systemSymbolName: "play.fill", action: #selector(playPauseButtonClicked(_:)))
        configureIconButton(nextButton, systemSymbolName: "forward.fill", action: #selector(nextButtonClicked(_:)))

        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked(_:))

        quitButton.target = self
        quitButton.action = #selector(quitButtonClicked(_:))
    }

    private func buildLayout() {
        let playbackStack = NSStackView(views: [previousButton, playPauseButton, nextButton])
        playbackStack.orientation = .horizontal
        playbackStack.alignment = .centerY
        playbackStack.distribution = .gravityAreas
        playbackStack.spacing = 12

        let buttonStack = NSStackView(views: [refreshButton, quitButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 8

        let stackView = NSStackView(views: [
            artworkImageView,
            titleLabel,
            subtitleLabel,
            timeLabel,
            stateLabel,
            playbackStack,
            buttonStack
        ])

        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .gravityAreas
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),

            artworkImageView.widthAnchor.constraint(equalToConstant: 224),
            artworkImageView.heightAnchor.constraint(equalTo: artworkImageView.widthAnchor),

            titleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            timeLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            stateLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 42),
            previousButton.heightAnchor.constraint(equalToConstant: 32),
            playPauseButton.widthAnchor.constraint(equalToConstant: 64),
            playPauseButton.heightAnchor.constraint(equalToConstant: 32),
            nextButton.widthAnchor.constraint(equalToConstant: 42),
            nextButton.heightAnchor.constraint(equalToConstant: 32),
            buttonStack.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }

    private func configureIconButton(_ button: NSButton, systemSymbolName: String, action: Selector) {
        button.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private func updatePlaybackButtons(with trackInfo: TrackInfo) {
        previousButton.isEnabled = trackInfo.canControlPlayback
        playPauseButton.isEnabled = trackInfo.canControlPlayback
        nextButton.isEnabled = trackInfo.canControlPlayback

        let playPauseSymbolName = trackInfo.playbackState == .playing ? "pause.fill" : "play.fill"
        let accessibilityDescription = trackInfo.playbackState == .playing ? "Pause" : "Play"

        playPauseButton.image = NSImage(
            systemSymbolName: playPauseSymbolName,
            accessibilityDescription: accessibilityDescription
        )
    }

    @objc private func previousButtonClicked(_ sender: NSButton) {
        onPreviousTrack?()
    }

    @objc private func playPauseButtonClicked(_ sender: NSButton) {
        onTogglePlayPause?()
    }

    @objc private func nextButtonClicked(_ sender: NSButton) {
        onNextTrack?()
    }

    @objc private func refreshButtonClicked(_ sender: NSButton) {
        onRefresh?()
    }

    @objc private func quitButtonClicked(_ sender: NSButton) {
        onQuit?()
    }
}
