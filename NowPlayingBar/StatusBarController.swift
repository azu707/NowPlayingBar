import AppKit

enum Metrics {
    static let popoverRefreshInterval: TimeInterval = 1
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
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let provider: NowPlayingProviding
    private let popover = NSPopover()
    private let popoverViewController: NowPlayingPopoverViewController
    private var timer: Timer?
    private var current = NowPlaying.unavailable(.notRunning)
    private var refreshGeneration = 0
    private var popoverRefreshTick = 0
    private var lastFetchDate: Date?

    init(provider: NowPlayingProviding) {
        self.provider = provider
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popoverViewController = NowPlayingPopoverViewController()

        super.init()

        configureStatusItem()
        configurePopover()
        startObservingMusic()
        refresh(force: true)
    }

    func invalidate() {
        stopPopoverRefreshTimer()
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
        popover.delegate = self

        popoverViewController.onRefresh = { [weak self] in
            self?.refresh(force: true)
        }

        popoverViewController.onPreviousTrack = {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                await self.provider.previousTrack()
                self.refresh(force: true)
            }
        }

        popoverViewController.onTogglePlayPause = {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                await self.provider.togglePlayPause()
                self.refresh(force: true)
            }
        }

        popoverViewController.onNextTrack = {
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

    private func startObservingMusic() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playerInfoDidChange(_:)),
            name: Notification.Name("com.apple.Music.playerInfo"),
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    private func startPopoverRefreshTimer() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: Metrics.popoverRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.popoverTimerFired()
            }
        }
    }

    private func stopPopoverRefreshTimer() {
        timer?.invalidate()
        timer = nil
        popoverRefreshTick = 0
    }

    private func popoverTimerFired() {
        popoverRefreshTick += 1
        popoverViewController.update(with: interpolatedNowPlaying())

        if popoverRefreshTick % 5 == 0 {
            refresh(force: false)
        }
    }

    private func refresh(force: Bool) {
        refreshGeneration += 1
        let generation = refreshGeneration

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let next = await self.provider.fetchNowPlaying()

            guard generation == self.refreshGeneration else {
                return
            }

            self.apply(next, force: force)
        }
    }

    private func apply(_ next: NowPlaying, force: Bool) {
        guard force || next != current else {
            return
        }

        current = next

        switch next {
        case .active:
            lastFetchDate = Date()
        case .unavailable:
            lastFetchDate = nil
        }

        updateStatusItem(with: next)
        popoverViewController.update(with: interpolatedNowPlaying())
    }

    private func interpolatedNowPlaying() -> NowPlaying {
        guard case .active(let trackInfo) = current, let lastFetchDate else {
            return current
        }

        return .active(trackInfo.interpolated(since: lastFetchDate))
    }

    private func updateStatusItem(with nowPlaying: NowPlaying) {
        guard let button = statusItem.button else {
            return
        }

        let title: String
        let toolTip: String

        switch nowPlaying {
        case .active(let trackInfo):
            title = truncate(trackInfo.menuBarTitle, maxLength: Metrics.menuBarTitleMaxLength)

            if title.isEmpty {
                toolTip = trackInfo.playbackState.displayName
            } else {
                toolTip = trackInfo.menuBarTitle
            }
        case .unavailable(let reason):
            title = ""
            toolTip = reason.message
        }

        button.title = title
        button.toolTip = toolTip
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

    @objc private func playerInfoDidChange(_ note: Notification) {
        refresh(force: true)
    }

    @objc private func workspaceApplicationDidTerminate(_ note: Notification) {
        guard let application = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.bundleIdentifier == "com.apple.Music" else {
            return
        }

        refresh(force: true)
    }

    func popoverWillShow(_ notification: Notification) {
        startPopoverRefreshTimer()
    }

    func popoverDidClose(_ notification: Notification) {
        stopPopoverRefreshTimer()
    }
}
