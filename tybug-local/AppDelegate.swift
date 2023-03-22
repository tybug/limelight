import Foundation
import Cocoa
import HotKey


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    static let dataDirPath = NSHomeDirectory() + "/Library/Application Support/tybug-local"
    let searcher: Searcher

    override init() {
        // ensure data dir exists
        if !FileManager.default.fileExists(atPath: Self.dataDirPath) {
            try! FileManager.default.createDirectory(atPath: Self.dataDirPath, withIntermediateDirectories: false)
        }

        // initiailize here instead of at the top level so we ensure that any AppDelegate initialization has
        // occurred. For instance, we want to ensure that the dataDirPath has been created, or searcher will
        // error when trying to access the db.
        searcher = Searcher()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

    }

    func applicationWillTerminate(_ aNotification: Notification) {

    }

    func applicationWillResignActive(_ notification: Notification) {
        // close searcher popup when clicking off it (which causes our app to move into the background)
        searcher.windowController.window?.close()
    }
}
