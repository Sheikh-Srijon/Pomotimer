import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: EdgePanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        panelController = EdgePanelController()
        panelController?.showPanel(expanded: false)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController?.showPanel(expanded: true)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.model.persist()
    }
}
