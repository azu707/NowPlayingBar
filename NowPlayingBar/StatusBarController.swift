import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let provider: MusicNowPlayingProvider
    private let popover = NSPopover()
    private let popoverViewController: NowPlayingPopoverViewController
    private var timer: Timer?
    private var currentTrack = TrackInfo.idle

    init(provider: MusicNowPlayingProvider) {
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
        popover.contentSize = NSSize(width: 300, height: 390)
        popover.contentViewController = popoverViewController

        popoverViewController.onRefresh = { [weak self] in
            self?.refresh(force: true)
        }

        popoverViewController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(force: false)
            }
        }
    }

    private func refresh(force: Bool) {
        let nextTrack = provider.fetchNowPlaying()

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

        let title = truncate(trackInfo.menuBarTitle, maxLength: 42)
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

        return "\(value.prefix(maxLength - 3))..."
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
