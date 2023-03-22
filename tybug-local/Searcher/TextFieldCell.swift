import Foundation
import AppKit


// https://stackoverflow.com/a/45847977

class SearcherTextFieldCell: NSTextFieldCell {

    private static let paddingTop: CGFloat    = 5
    private static let paddingBottom: CGFloat = 5

    private static let paddingRight: CGFloat  = 10
    private static let paddingLeft: CGFloat   = 0

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += Self.paddingTop + Self.paddingBottom
        return size
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        return Self.inset(rect)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = Self.inset(rect)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = Self.inset(rect)
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = Self.inset(cellFrame)
        super.drawInterior(withFrame: insetRect, in: controlView)
    }

    static func inset(_ rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.minX + Self.paddingLeft,
            y: rect.minY + Self.paddingTop,
            width: rect.width - Self.paddingLeft - Self.paddingRight,
            height: rect.height - Self.paddingBottom - Self.paddingTop
        )
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        // block any drawing from occuring. All the drawing, including the background and rounded corners, is handled by SearcherTextStackView.
    }
}
