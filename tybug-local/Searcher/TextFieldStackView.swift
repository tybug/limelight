import Foundation
import Cocoa

class SearcherTextFieldStackView : NSView {
    var hasResults: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        var corners: [NSCorner]
        if hasResults {
            // TODO this is completely wrong. This should be [.upperLeft, .upperRight], but something is
            // wrong in makeRoundedPath that makes it inverted. I don't know why.
            corners = [.lowerLeft, .lowerRight]
        } else {
            corners = [.upperLeft, .upperRight, .lowerLeft, .lowerRight]
        }

        let path = makeRoundedPath(dirtyRect, radius: 10, roundCorners: corners)
        path.lineWidth = 0.2

        Searcher.backgroundColor.set()
        path.fill()

        let c: CGFloat = 20 / 255
        let color = NSColor(red: c, green: c, blue: c, alpha: 1)
        color.set()
        path.stroke()
    }
}
