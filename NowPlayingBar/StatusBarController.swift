import AppKit

enum Metrics {
    static let pollingInterval: TimeInterval = 2
    static let menuBarTitleMaxLength = 42
    static let popoverSize = NSSize(width: 300, height: 430)
    static let artworkSide: CGFloat = 224
    static let contentInset: CGFloat = 18
    static let contentSpacing: CGFloat = 12
    static let buttonSpacing: CGFloat = 8
    static let iconButtonSize = NSSize(width: 42, height: 32)
    static let playPauseButtonWidth: CGFloat = 64
    static let playbackStackWidth: CGFloat = 184
}

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let provider: NowPlayingProviding
    private let popover = NSPopover()
    private let popoverViewController: NowPlayingPopoverViewController
    private var timer: Timer?
    private var currentTrack = TrackInfo.idle
    private var refreshGeneration = 0

    init(provider: NowPlayingProviding) {
        self.provider = provider
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popoverViewController = NowPlayingPopoverViewController()

        super.init()

        configureStatusItem()
        configurePopover()
        startPolling()
        refresh(force: true)
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NowPlayingBar")
        button.imagePosition = .imageLeading
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.toolTip = "NowPlayingBar"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = Metrics.popoverSize
        popover.contentViewController = popoverViewController

        popoverViewController.onRefresh = { [weak self] in
            self?.refresh(force: true)
        }

        popoverViewController.onPreviousTrack = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                await self.provider.previousTrack()
                self.refresh(force: true)
            }
        }

        popoverViewController.onTogglePlayPause = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                await self.provider.togglePlayPause()
                self.refresh(force: true)
            }
        }

        popoverViewController.onNextTrack = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                await self.provider.nextTrack()
                self.refresh(force: true)
            }
        }

        popoverViewController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: Metrics.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(force: false)
            }
        }
    }

    private func refresh(force: Bool) {
        refreshGeneration += 1
        let generation = refreshGeneration

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let nextTrack = await self.provider.fetchNowPlaying()

            guard generation == self.refreshGeneration else {
                return
            }

            self.apply(nextTrack, force: force)
        }
    }

    private func apply(_ nextTrack: TrackInfo, force: Bool) {
        guard force || nextTrack != currentTrack else {
            return
        }

        currentTrack = nextTrack
        updateStatusItem(with: nextTrack)
        popoverViewController.update(with: nextTrack)
    }

    private func updateStatusItem(with trackInfo: TrackInfo) {
        guard let button = statusItem.button else {
            return
        }

        let title = truncate(trackInfo.menuBarTitle, maxLength: Metrics.menuBarTitleMaxLength)
        button.title = title

        if title.isEmpty {
            button.toolTip = trackInfo.message ?? trackInfo.playbackState.displayName
        } else {
            button.toolTip = trackInfo.menuBarTitle
        }
    }

    private func truncate(_ value: String, maxLength: Int) -> String {
        guard value.count > maxLength else {
            return value
        }

        return "\(value.prefix(maxLength - 1))…"
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            refresh(force: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
