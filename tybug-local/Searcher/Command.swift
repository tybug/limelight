import Foundation
import SQLite

class SearcherCommand {
    let name: String
    let callback: () -> SearcherCommandWidget?

    init(name: String, callback: @escaping () -> SearcherCommandWidget?) {
        self.name = name
        self.callback = callback
    }

    func run() -> SearcherCommandWidget? {
        return callback()
    }
}

class SearcherCommandWidget {
    var searcher: SearcherViewController?
    var clearResultsDeferred = false
    var clearResultsDeferredType: AnyClass? = nil
    // true to display text as bullets (password entry style)
    var useSecureTextEntry: Bool { false }

    func addResultView(_ resultView: SearcherResultView) {
        if clearResultsDeferred {
            flushClearResults()
        }
        searcher!.addResultView(resultView)
    }

    func flushClearResults() {
        searcher!.clearResults(ofType: clearResultsDeferredType)
        clearResultsDeferred = false
        clearResultsDeferredType = nil
    }

    func clearResults(ofType type: AnyClass? = nil) {
        // clearing results immediately here would result in flickering between "some results",
        // "no results", and "some results" again as clearResults gets called milliseconds before
        // addResultView. Instead, we'll defer clearing until the first addResultView call after this
        // clearResults call.
        // We could expand this in the future to include "transactions", which are groups of addResultView
        // calls which must be shown at the same time, and so we won't clear or add results to searcher until
        // the transaction is finished.
        clearResultsDeferred = true
        clearResultsDeferredType = type
    }

    func doOnTextChanged(stringValue: String) {
        onTextChanged(stringValue: stringValue)
        // if onTextChanged calls clearResults and doesn't add any results, we need to flush the
        // deferred clearResults call.
        if clearResultsDeferred {
            flushClearResults()
        }
    }

    func onTextChanged(stringValue: String) {
        fatalError("subclasses of SearcherCommandWidget must implement onTextChanged(stringValue: String)")
    }

    func onReturnPressed() -> SearcherCommandWidget? {
        // return the command widget to return to if handled
        return nil
    }

    // force evaluation of the statement. Our sqlite wrapper library defers evaluation of statements
    // until iteration, but we often/always want to control when it evaluates (ie, on a non-main thread).
    func statementToList(_ statement : Statement) -> [Statement.Element] {

        var rows: [Statement.Element] = []
        for row in statement {
            rows.append(row)
        }
        return rows
    }
}
