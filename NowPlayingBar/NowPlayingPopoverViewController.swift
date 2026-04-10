import AppKit

@MainActor
final class NowPlayingPopoverViewController: NSViewController {
    var onRefresh: (() -> Void)?
    var onQuit: (() -> Void)?

    private let artworkImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let stateLabel = NSTextField(labelWithString: "")
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
        stateLabel.stringValue = trackInfo.message ?? trackInfo.playbackState.displayName

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

        stateLabel.font = .systemFont(ofSize: 12)
        stateLabel.alignment = .center
        stateLabel.lineBreakMode = .byTruncatingTail
        stateLabel.maximumNumberOfLines = 2
        stateLabel.textColor = .tertiaryLabelColor

        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked(_:))

        quitButton.target = self
        quitButton.action = #selector(quitButtonClicked(_:))
    }

    private func buildLayout() {
        let buttonStack = NSStackView(views: [refreshButton, quitButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 8

        let stackView = NSStackView(views: [
            artworkImageView,
            titleLabel,
            subtitleLabel,
            stateLabel,
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
            stateLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }

    @objc private func refreshButtonClicked(_ sender: NSButton) {
        onRefresh?()
    }

    @objc private func quitButtonClicked(_ sender: NSButton) {
        onQuit?()
    }
}
