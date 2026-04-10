import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(provider: MusicNowPlayingProvider())
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.invalidate()
        statusBarController = nil
    }
}
