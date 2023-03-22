import Foundation
import AppKit

// nswindows with a style mask of .borderless can't become key windows by default, but we
// need our search window to become key so it can receieve keypresses on its text field.
class KeyNSWindow: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

class SearcherWindowController: NSWindowController {

    override func windowDidLoad() {
        // prevent windowbackground from showing in places where our text field doen't take
        // up the full window
        window?.isOpaque = true
        window?.backgroundColor = .clear

        // remove the fullscreen/close/minimize buttons and title bar
        window?.styleMask = [.borderless]

        window?.center()
    }
}
