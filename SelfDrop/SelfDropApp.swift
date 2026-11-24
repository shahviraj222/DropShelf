import AppKit

@main
@MainActor
final class SelfDropApp: NSObject, NSApplicationDelegate {
    private var shelf: ShelfWindowController?

    static func main() {
        let app = NSApplication.shared
        let delegate = SelfDropApp()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit DropShelf", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApplication.shared.mainMenu = menu
        shelf = ShelfWindowController()
        shelf?.showWindow(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        shelf?.close()
        shelf = nil
    }
}
