import Foundation
import HotKey
import SQLite


extension Notification.Name {
    static let onSearchResultOpened = Notification.Name("tybug-local-on-search-result-opened")
}


class Searcher {
    static let dbPath = URL(fileURLWithPath: AppDelegate.dataDirPath).appendingPathComponent("searcher.db").path

    let searchHotKey = HotKey(key: .space, modifiers: [.command])
    let storyboard = NSStoryboard(name: "Searcher", bundle: nil)
    var windowController: SearcherWindowController

    // match spotlight background color (mostly)
    static let backgroundColor = NSColor(
        red:   233 / 255,
        green: 233 / 255,
        blue:  233 / 255,
        alpha: 1
    )

    // match spotlight highlight color (mostly)
    static let highlightColor = NSColor(
        red:   61  / 255,
        green: 145 / 255,
        blue:  255 / 255,
        alpha: 1
    )

    let db: Connection

    init() {
        // completely recreate the database every run. Avoids consistency issues. Creating
        // the database is (surprisingly?) fast enough that this is feasible (takes ~5 secs).
        if FileManager.default.fileExists(atPath: Self.dbPath) {
            try! FileManager.default.removeItem(atPath: Self.dbPath)
        }
        Self.createDatabase()

        db = try! Connection(Self.dbPath)

        windowController = storyboard.instantiateController(withIdentifier: "searcherWindowController") as! SearcherWindowController
        searchHotKey.keyDownHandler = handleSearch

        NotificationCenter.default.addObserver(self, selector: #selector(closeWindow), name: .onSearchResultOpened, object: nil)

        // I can't for the life of me figure out how to do mouseDown handling on textfields and
        // text cells, so I'm going for the nuclear option of matching all mouse downs here.
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            let viewController = self.windowController.contentViewController as! SearcherViewController
            let fieldEditor = self.windowController.window?.fieldEditor(true, for: viewController.textField) as! NSTextView

            // might be necessary to get the correct size for usedRect, might not be...
            // https://groups.google.com/g/cocoa-dev/c/M-ISgRaMQGU/m/SimrcMT8N6sJ
            fieldEditor.layoutManager?.ensureLayout(for: fieldEditor.textContainer!)
            let textRect = fieldEditor.layoutManager?.usedRect(for: fieldEditor.textContainer!)

            // TODO only perform drag if `event.locationInWindow` is not inside of textRect + some padding.
            // ie, don't move the window if we drag on the text. We want to allow highlighting the text with drags.

            self.windowController.window?.performDrag(with: event)
            return event
        }

        index()
    }

    static func createDatabase() {
        let db = try! Connection(dbPath)
        try! db.execute(
            """
            CREATE TABLE file (
                name STRING NOT NULL,
                name_normalized STRING NOT NULL,
                dir STRING NOT NULL,
                dir_normalized STRING NOT NULL,
                type STRING NOT NULL,
                UNIQUE(name, dir)
            )
            """
        )
        // separate indexes on everything. Some of these might be pointless, but just covering my bases
        try! db.execute(
            """
            CREATE INDEX idx_file_name
                ON file(name)
            """
        )
        try! db.execute(
            """
            CREATE INDEX idx_file_name_normalized
                ON file(name_normalized)
            """
        )
        try! db.execute(
            """
            CREATE INDEX idx_file_dir
                ON file(dir)
            """
        )
        try! db.execute(
            """
            CREATE INDEX idx_file_dir_normalized
                ON file(dir_normalized)
            """
        )
        try! db.execute(
            """
            CREATE INDEX idx_file_type
                ON file(type)
            """
        )
    }

    func handleSearch() {
        if windowController.window?.isVisible ?? false {
            closeWindow()
        } else {
            windowController.showWindow(self)
            let searcherViewController = windowController.contentViewController as! SearcherViewController
            searcherViewController.onShow()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func index() {
        print("started indexing")
        var numIndexed = 0

        // insert in a transaction for speed
        try! db.run("BEGIN TRANSACTION")

        let desktop = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop").path
        for path in ["/Applications", "/System/Applications", desktop] {
            let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)!

            for case let file as URL in enumerator {
                // normalize strings with unicode normalization form NFKC. Either NFKC or NFKD will probably
                // work fine, as long as we're consistent about which normalization form we use when normalizing
                // both db entries and queries. What's important is that we use a compatability normalization
                // form (the K variants) and not NFC or NFD. By using compatability normalization, we allow
                // things like normal 2 to match superscript 2.
                // https://unicode.org/reports/tr15/
                let name = file.lastPathComponent
                let nameNormalized = name.precomposedStringWithCompatibilityMapping
                let dir = file.deletingLastPathComponent().path
                let dirNormalized = dir.precomposedStringWithCompatibilityMapping


                let isDirectory = try! file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory!
                let type = isDirectory ? "dir" : "file"

                // apps have tons of resource files I can't imagine myself ever caring about. We'll index
                // the app itself, but not any of its contents.
                if isDirectory && file.pathExtension == "app" {
                    enumerator.skipDescendants()
                }

                // don't index inside node_modules
                if isDirectory && name == "node_modules" {
                    enumerator.skipDescendants()
                }

                // don't index inside git directories
                if isDirectory && name == ".git" {
                    enumerator.skipDescendants()
                }

                // skip .DS_Store files
                if name == ".DS_Store" {
                    continue
                }

                numIndexed += 1
                try! db.run("INSERT OR IGNORE INTO file VALUES (?, ?, ?, ?, ?)", [name, nameNormalized, dir, dirNormalized, type])

                if numIndexed % 10_000 == 0 {
                    print("files indexed: \(numIndexed)")
                }
            }
        }
        try! db.run("COMMIT")
        print("done indexing")
    }

    @objc func closeWindow() {
        windowController.window?.close()
        // return focus to previously focused application
        NSApp.hide(self)
    }
}
