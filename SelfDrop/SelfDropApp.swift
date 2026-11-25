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
        // Use the compiled catalog icon for the running app as well as bundle discovery.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About DropShelf", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        let showItem = appMenu.addItem(withTitle: "Show Shelf", action: #selector(showShelf), keyEquivalent: "s")
        showItem.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(withTitle: "How to Use DropShelf", action: #selector(showUsage), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit DropShelf", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApplication.shared.mainMenu = menu
        shelf = ShelfWindowController()
        shelf?.showWindow(nil)
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "DropShelf",
            .credits: NSAttributedString(string:
                "A temporary native shelf for files, folders and recent screenshots.\n" +
                "Built with Swift and AppKit. Originals stay untouched.\n" +
                "App icon supplied by the project owner.")
        ])
    }

    @objc private func showShelf() {
        shelf?.openShelf()
    }

    @objc private func showUsage() {
        let alert = NSAlert()
        alert.messageText = "Keep files within reach"
        alert.informativeText =
            "Drop files onto the blue edge tab, then click it to open the shelf.\n\n" +
            "Cmd-click or long press to select multiple tiles, then drag them into a destination.\n\n" +
            "Choose your screenshot save folder to collect new screenshots: newest 10, one-hour expiry.\n\n" +
            "Remove selected and Clear all remove references only. Stop turns off screenshot collection."
        alert.addButton(withTitle: "Got it")
        alert.runModal()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        shelf?.openShelf()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        shelf?.close()
        shelf = nil
    }
}
