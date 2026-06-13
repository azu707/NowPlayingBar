import AppKit

@MainActor
final class NowPlayingPopoverViewController: NSViewController {
    var onRefresh: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onSeek: ((Double) -> Void)?
    var onQuit: (() -> Void)?

    private let artworkImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let remainingLabel = NSTextField(labelWithString: "")
    private let stateLabel = NSTextField(labelWithString: "")
    private let previousButton = NSButton(title: "", target: nil, action: nil)
    private let playPauseButton = NSButton(title: "", target: nil, action: nil)
    private let nextButton = NSButton(title: "", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)
    private var isScrubbing = false

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configureSubviews()
        buildLayout()
        update(with: .unavailable(.notRunning))
    }

    func update(with nowPlaying: NowPlaying) {
        switch nowPlaying {
        case .active(let trackInfo):
            updateActiveTrack(trackInfo)
        case .unavailable(let reason):
            updateUnavailable(reason)
        }
    }

    private func updateActiveTrack(_ trackInfo: TrackInfo) {
        titleLabel.stringValue = trackInfo.detailTitle
        subtitleLabel.stringValue = trackInfo.detailSubtitle
        updateTimeControls(with: trackInfo)
        stateLabel.stringValue = trackInfo.playbackState.displayName
        updatePlaybackButtons(playbackState: trackInfo.playbackState, isEnabled: true)

        if let artworkData = trackInfo.artworkData, let image = NSImage(data: artworkData) {
            artworkImageView.image = image
        } else {
            artworkImageView.image = NSImage(
                systemSymbolName: "music.note",
                accessibilityDescription: "No artwork"
            )
        }
    }

    private func updateUnavailable(_ reason: UnavailableReason) {
        titleLabel.stringValue = unavailableTitle(for: reason)
        subtitleLabel.stringValue = reason.message
        updateTimeControls(with: nil)
        stateLabel.stringValue = reason.message
        updatePlaybackButtons(playbackState: .stopped, isEnabled: false)
        artworkImageView.image = NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "No artwork"
        )
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

        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        elapsedLabel.alignment = .right
        elapsedLabel.lineBreakMode = .byTruncatingTail
        elapsedLabel.textColor = .secondaryLabelColor

        seekSlider.controlSize = .small
        seekSlider.isContinuous = true
        seekSlider.target = self
        seekSlider.action = #selector(sliderMoved(_:))

        remainingLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        remainingLabel.alignment = .left
        remainingLabel.lineBreakMode = .byTruncatingTail
        remainingLabel.textColor = .secondaryLabelColor

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
        let timeStack = NSStackView(views: [elapsedLabel, seekSlider, remainingLabel])
        timeStack.orientation = .horizontal
        timeStack.alignment = .centerY
        timeStack.distribution = .fill
        timeStack.spacing = Metrics.buttonSpacing

        let playbackStack = NSStackView(views: [previousButton, playPauseButton, nextButton])
        playbackStack.orientation = .horizontal
        playbackStack.alignment = .centerY
        playbackStack.distribution = .equalCentering
        playbackStack.spacing = Metrics.contentSpacing

        let buttonStack = NSStackView(views: [refreshButton, quitButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = Metrics.buttonSpacing

        let stackView = NSStackView(views: [
            artworkImageView,
            titleLabel,
            subtitleLabel,
            timeStack,
            stateLabel,
            playbackStack,
            buttonStack
        ])

        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .gravityAreas
        stackView.spacing = Metrics.contentSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.contentInset),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.contentInset),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: Metrics.contentInset),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Metrics.contentInset),

            artworkImageView.widthAnchor.constraint(equalToConstant: Metrics.artworkSide),
            artworkImageView.heightAnchor.constraint(equalTo: artworkImageView.widthAnchor),

            titleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            timeStack.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            elapsedLabel.widthAnchor.constraint(equalToConstant: Metrics.timeLabelWidth),
            remainingLabel.widthAnchor.constraint(equalToConstant: Metrics.timeLabelWidth),
            stateLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: Metrics.iconButtonSize.width),
            previousButton.heightAnchor.constraint(equalToConstant: Metrics.iconButtonSize.height),
            playPauseButton.widthAnchor.constraint(equalToConstant: Metrics.playPauseButtonWidth),
            playPauseButton.heightAnchor.constraint(equalToConstant: Metrics.iconButtonSize.height),
            nextButton.widthAnchor.constraint(equalToConstant: Metrics.iconButtonSize.width),
            nextButton.heightAnchor.constraint(equalToConstant: Metrics.iconButtonSize.height),
            playbackStack.widthAnchor.constraint(equalToConstant: Metrics.playbackStackWidth),
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

    private func updatePlaybackButtons(playbackState: PlaybackState, isEnabled: Bool) {
        previousButton.isEnabled = isEnabled
        playPauseButton.isEnabled = isEnabled
        nextButton.isEnabled = isEnabled

        let playPauseSymbolName = playbackState == .playing ? "pause.fill" : "play.fill"
        let accessibilityDescription = playbackState == .playing ? "Pause" : "Play"

        playPauseButton.image = NSImage(
            systemSymbolName: playPauseSymbolName,
            accessibilityDescription: accessibilityDescription
        )
    }

    private func updateTimeControls(with trackInfo: TrackInfo?) {
        guard !isScrubbing else {
            return
        }

        guard let trackInfo,
              let elapsedTime = trackInfo.elapsedTime,
              let duration = trackInfo.duration else {
            elapsedLabel.stringValue = ""
            remainingLabel.stringValue = ""
            seekSlider.minValue = 0
            seekSlider.maxValue = 1
            seekSlider.doubleValue = 0
            seekSlider.isEnabled = false
            return
        }

        let clampedElapsedTime = min(max(elapsedTime, 0), duration)

        elapsedLabel.stringValue = formatTime(clampedElapsedTime)
        remainingLabel.stringValue = "-\(formatTime(duration - clampedElapsedTime))"
        seekSlider.minValue = 0
        seekSlider.maxValue = duration
        seekSlider.doubleValue = clampedElapsedTime
        seekSlider.isEnabled = true
    }

    private func updateTimePreview(_ seconds: Double) {
        let duration = seekSlider.maxValue
        let clampedSeconds = min(max(seconds, 0), duration)

        elapsedLabel.stringValue = formatTime(clampedSeconds)
        remainingLabel.stringValue = "-\(formatTime(duration - clampedSeconds))"
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let seconds = max(Int(timeInterval.rounded(.down)), 0)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func unavailableTitle(for reason: UnavailableReason) -> String {
        switch reason {
        case .notRunning:
            return "Music is not running"
        case .permissionDenied:
            return "Music access is not allowed"
        case .error:
            return "Unable to read Music"
        }
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

    @objc private func sliderMoved(_ sender: NSSlider) {
        isScrubbing = true
        updateTimePreview(sender.doubleValue)

        if NSApp.currentEvent?.type == .leftMouseUp {
            isScrubbing = false
            onSeek?(sender.doubleValue)
        }
    }

    @objc private func refreshButtonClicked(_ sender: NSButton) {
        onRefresh?()
    }

    @objc private func quitButtonClicked(_ sender: NSButton) {
        onQuit?()
    }
}
