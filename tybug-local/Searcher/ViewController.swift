import Foundation
import Cocoa
import SQLite
import HotKey


let searcherCommands = [
    SearcherCommand(name: "off") {
        NSApp.terminate(nil)
        return nil
    },
    SearcherCommand(name: "full") {
        let applescript = NSAppleScript(source:
            """
            # either I'm not accounting for a handful of pixels somewhere or dockWidth isn't returning the actual visual
            # width of the dock. Either way we need to move our windows some adjustment number of additional pixels to
            # the right to have them nicely line up with the dock.
            set adjustmentPixels to 6

            tell application "System Events" to ¬
                tell application process "Dock" to ¬
                    set {dockWidth, dockHeight} to ¬
                        the size of list 1

            tell application "Finder" to ¬
                set {topLeftX, topLeftY, bottomRightX, bottomRightY} to bounds of window of desktop

            tell application "System Events"
                set frontApp to first application process whose frontmost is true
                set frontAppName to name of frontApp
                tell process frontAppName
                    tell (1st window whose value of attribute "AXMain" is true)
                        # setting bounds (`set bounds to {dockWidth, 0, bottomRightX - dockWidth, bottomRightY}`)
                        # doesn't work here for whatever reason, so set position and size independently.
                        set position to {dockWidth + adjustmentPixels, 0}
                        set size to {bottomRightX - dockWidth - adjustmentPixels, bottomRightY}
                    end tell
                end tell
            end tell
            """
        )!
        Utils.shared.runApplescript(applescript)
        return nil
    }
]

class DefaultCommandWidget: SearcherCommandWidget {
    var db: Connection? = nil

    override init() {
        db = try! Connection(Searcher.dbPath)
    }

    override func onTextChanged(stringValue: String) {
        // normalize by NFKC to match our db normalization
        var stringValue = stringValue.precomposedStringWithCompatibilityMapping

        // if we cleared the query, just clear our results display
        if stringValue == "" {
            clearResults()
            return
        }

        // if the search starts with a question mark, force a file search, not a mathematical expression. Same concept as
        // starting with a ? in google searches to avoid domain autorecognition.
        var forceQuery = false
        if stringValue.starts(with: "?") {
            forceQuery = true
            stringValue.removeFirst()
        }

        // parse mathematical expressions
        let characterSet = CharacterSet(["*", "^", "/", "(", ")", "+", "&", " ", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "-"])
        if stringValue.allSatisfy({
            $0.unicodeScalars.allSatisfy({characterSet.contains($0)})
        }) && !forceQuery {
            clearResults()
            // rely on MathParser to automatically detect between infix and rpn notation.
            guard let val = MathPaser.parse(stringValue) else {
                return
            }
            let resultView = MathResultView(val)
            addResultView(resultView)
            return
        } else {
            // if we're not in math mode, get rid of all math expressions. Ideally these would be cleared
            // elsewhere, but there's some edge cases (typing after cmd+space which selects all) where a
            // clearresults call may not occur.
            clearResults(ofType: MathResultView.self)
        }

        if stringValue.hasPrefix(">") {
            clearResults()
            for searcherCommand in searcherCommands {
                if (">" + searcherCommand.name).starts(with: stringValue) {
                    let resultView = CommandResultView(command: searcherCommand)
                    addResultView(resultView)
                }
            }
            return
        }

        // if we have a >, but not in the beginning of the string, try and match it by treating each
        // word separated by > as a directory
        if stringValue.contains(">") {
            // TODO handle multiple > or :> in the same query, will probably require reworking how we handle clauses

            // start trivially true to allow for easy appending of clauses later.
            var dirQuery = "1"
            var dirQueryArgs: [String] = []
            var currentPart = ""
            var i = 0
            while true {
                if i >= stringValue.count {
                    break
                }

                let character = stringValue[i]

                if character == ":" && i + 1 < stringValue.count && stringValue[i + 1] == ">" {
                    // matching files in `currentQuery`'s directory or nested directories
                    dirQuery.append(" AND (dir_normalized LIKE ? OR dir_normalized LIKE ?)")
                    dirQueryArgs.append(contentsOf: ["%/\(currentPart)/%", "%/\(currentPart)"])

                    currentPart = ""
                    i += 2
                    continue
                }

                if character == ">" {
                    // matching files in `currentQuery`'s directory, no nested directories
                    dirQuery.append(" AND (dir_normalized LIKE ?)")
                    dirQueryArgs.append(contentsOf: ["%\(currentPart)"])

                    currentPart = ""
                    i += 1
                    continue
                }

                currentPart.append(character)
                i += 1
            }

            // any remaining text becomes the name query. It's ok if this is the empty string, because then our query is
            // `name_normalized LIKE %%`, which is always true.
            let nameQuery = currentPart

            // run sqlite on separate thread so we don't block ui
            DispatchQueue.global(qos: .userInitiated).async {
                let statement = try! self.db!.run(
                    """
                    SELECT * FROM file
                    WHERE \(dirQuery) AND name_normalized LIKE ?
                    ORDER BY LENGTH(name) ASC
                    LIMIT 10
                    """,
                    dirQueryArgs + ["%\(nameQuery)%"]
                )
                let rows = self.statementToList(statement)

                self.processSqliteRows(rows)
            }
            return
        }

        // run sqlite on separate thread so we don't block ui
        DispatchQueue.global(qos: .userInitiated).async {
            let statement = try! self.db!.run("SELECT * FROM file WHERE name_normalized LIKE ? ORDER BY LENGTH(name) ASC LIMIT 10", "%\(stringValue)%")
            let rows = self.statementToList(statement)

            // TODO include aliases from `(NSApp.delegate as! AppDelegate).config` in search

            self.processSqliteRows(rows)
        }
    }

    func processSqliteRows(_ rows: [Statement.Element]) {
        // kick back to main thread (callee called us on a separate thread) so we can perform ui operations
        DispatchQueue.main.async {
            // only clear fileresultviews (ie the resultviews that this function itself added).
            // we don't want to clear other resultviews that other sources may have added, such as
            // commandresultviews.
            self.clearResults(ofType: FileResultView.self)

            for row in rows {
                // XXX: don't use `row[0] as! String`; our sqlite wrapper seems to do type conversion
                // behind the scenes, so even though our column has type TEXT, if an entry looks like
                // a double (eg "2.9") it will be returned as a double here and the force-cast will fail.
                // Use a convert to string instead.
                let name = String(describing: row[0]!)
                let nameNormalized = String(describing: row[1]!)
                let dir = String(describing: row[2]!)
                let dirNormalized = String(describing: row[3]!)

                let resultView = FileResultView(name, dir)
                self.addResultView(resultView)
            }

            // because this is happening async, we may have a deferred clearResults call if no new rows are added and we execute
            // after `doOnTextChanged` finishes. Flush manually if no new rows were added.
            if rows.isEmpty {
                self.flushClearResults()
            }
        }
    }
}

class SearcherViewController: NSViewController, NSUserNotificationCenterDelegate, NSTextFieldDelegate, NSControlTextEditingDelegate {

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var resultsStackView: NSStackView!
    @IBOutlet weak var textFieldStackView: SearcherTextFieldStackView!

    var selectedIndex: Int? = nil

    var numResults: Int = 0 {
        didSet {
            textFieldStackView.hasResults = numResults > 0
        }
    }

    var stringValue: String {
        get {
            return textField.stringValue
        }
        set {
            textField.stringValue = newValue
        }
    }

    var currentWidget: SearcherCommandWidget? {
        didSet {
            currentWidget?.searcher = self
            // changing to a new widget always clears result and stored text
            clearResults()
            stringValue = ""
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        currentWidget = DefaultCommandWidget()

        NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: onKeyDown)

        textField.font = NSFont.systemFont(ofSize: 28)

        // disable blue focus ring around text field
        textField.focusRingType = .none
        textField.delegate = self
    }

    func onShow() {
        // mimic spotlight behavior, where all text is selected whenever spotlight is opened.
        textField.selectText(self)
    }

    func controlTextDidChange(_ obj: Notification) {
        currentWidget!.doOnTextChanged(stringValue: stringValue)
    }

    func onKeyDown(with event: NSEvent) -> NSEvent? {
        let previousIndex = selectedIndex
        var opened = false

        switch UInt32(event.keyCode) {
        case Key.downArrow.carbonKeyCode:
            if selectedIndex == nil && resultsStackView.subviews.count > 0 {
                selectedIndex = 0
            } else if (selectedIndex != nil) && selectedIndex! < resultsStackView.subviews.count - 1 {
                selectedIndex = selectedIndex! + 1
            }
        case Key.upArrow.carbonKeyCode:
            if selectedIndex == 0 {
                selectedIndex = nil
            } else if selectedIndex != nil {
                selectedIndex = selectedIndex! - 1
            }
        case Key.rightArrow.carbonKeyCode:
            // ignore command + right, which I use for navigation
            if event.modifierFlags.contains(.command) {
                break
            }

            if let fileResultView = selectedResult() as? FileResultView {

                var baseString = ""
                var currentPart = ""
                var i = 0
                while i < stringValue.count {
                    let c = stringValue[i]

                    currentPart += String(c)

                    if c == ">" {
                        baseString += currentPart
                        currentPart = ""
                        i += 1
                        continue
                    }

                    if c == ":" && i < stringValue.count - 1 && stringValue[i + 1] == ">" {
                        baseString += currentPart + ">"
                        currentPart = ""
                        i += 2
                        continue
                    }

                    if c == "/" {
                        baseString += currentPart
                        currentPart = ""
                        i += 1
                        continue
                    }

                    i += 1
                }

                stringValue = baseString + fileResultView.stringValue
            }
        case Key.return.carbonKeyCode:
            let newWidget = currentWidget?.onReturnPressed()
            if newWidget != nil {
                currentWidget = newWidget
                // close the searcher if we're returning to the default widget
                opened = newWidget is DefaultCommandWidget
                break
            }

            let selectedResult = selectedResult()
            var result: SearcherResultView? = nil
            if selectedResult != nil {
                result = selectedResult
            } else {
                // if we press enter while not selecting anything, but we have results,
                // select the first result
                if resultsStackView.subviews.count > 0 {
                    result = (resultsStackView.subviews[0] as! SearcherResultView)
                }
            }

            if result != nil {
                let searcherCommandWidget = result!.onSelected(event.modifierFlags)
                opened = result!.closeOnSelected

                if searcherCommandWidget != nil {
                    currentWidget = searcherCommandWidget
                    // only close the searcher if we're returning to the default widget, regardless of what closeOnSelected says
                    opened = searcherCommandWidget is DefaultCommandWidget
                }
            }
        case Key.escape.carbonKeyCode:
            // we didn't actually select anything, this is just a hacky way of posting our custom
            // notification and therefore closing the searcher window. Should probably split
            // into a separate notification (or rename the existing notification to
            // closeSearcherWindow).
            opened = true
        default:
            break
        }

        if opened {
            NotificationCenter.default.post(name: .onSearchResultOpened, object: nil)
        }

        let handled = opened || previousIndex != selectedIndex
        if handled {
            updateSelected()
        }

        // return nil if we want to block propagation of this event
        return handled ? nil : event
    }

    func updateSelected() {
        for view in resultsStackView.subviews {
            let resultView = view as! SearcherResultView
            resultView.selected = false
        }

        selectedResult()?.selected = true
    }

    func selectedResult() -> SearcherResultView? {
        if selectedIndex == nil {
            return nil
        }

        return (resultsStackView.subviews[selectedIndex!] as! SearcherResultView)
    }


    func addResultView(_ resultView: SearcherResultView) {
        // have to add before we activate constraints so that we can reference
        // textField.widthAnchor - you're not allowed to link two constraints which aren't
        // in the same view hierarchy.
        self.resultsStackView.addView(resultView, in: .bottom)

        resultView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resultView.widthAnchor.constraint(equalTo: resultsStackView.widthAnchor),
            resultView.heightAnchor.constraint(equalToConstant: 28),
        ])

        updateNumResults()
    }

    func clearResults(ofType type: AnyClass? = nil) {
        for resultView in resultsStackView.views {
            if type != nil && !resultView.isKind(of: type!) {
                continue
            }
            resultView.removeFromSuperview()
        }

        // clearing results invalidates the selected index.
        selectedIndex = nil

        updateNumResults()
    }

    func updateNumResults() {
        numResults = resultsStackView.subviews.count
    }
}
