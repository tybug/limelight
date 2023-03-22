import Foundation
import Cocoa

class SearcherResultView: NSTextField {

    override var isEditable: Bool {
        get { return false }
        set { }
    }
    override var isSelectable: Bool {
        get { return false }
        set { }
    }
    
    // should be true if you want searcher to hide itself after (eg you opened something in finder
    // as a result of this call), and false if you don't (eg you didn't take any action on this call)
    var closeOnSelected: Bool {
        get { return false }
    }

    var selected: Bool = false {
        didSet {
            (cell as! SearcherResultViewCell).selected = selected
            // redraw cell on selected
            needsDisplay = true
        }
    }

    // use our custom cell class.
    public override class var cellClass: AnyClass? {
        get { SearcherResultViewCell.self }
        set { }
    }

    init(_ displayValue: String) {
        super.init(frame: .zero)

        font = NSFont.systemFont(ofSize: 16)
        stringValue = displayValue
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func onSelected(_ modifierFlags: NSEvent.ModifierFlags) -> SearcherCommandWidget? {
        return nil
    }
}

class SearcherResultViewCell : NSTextFieldCell {
    private static let paddingTop:    CGFloat = 2
    private static let paddingBottom: CGFloat = 2

    private static let paddingRight:  CGFloat = 5
    private static let paddingLeft:   CGFloat = 10

    var selected = false

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
        let path = makeRoundedPath(cellFrame, radius: 10, roundCorners: [])
        path.lineWidth = 0.2

        Searcher.backgroundColor.set()

        if selected {
            Searcher.highlightColor.set()
        }

        path.fill()

        // draw the text, centered vertically in the cell
        let size = attributedStringValue.size()
        let y = (cellFrame.height - size.height) / 2


        let string = NSMutableAttributedString(attributedString: attributedStringValue)

        var attributes: [NSAttributedString.Key: Any] = [:]
        if selected {
            attributes = [NSAttributedString.Key.foregroundColor : NSColor.white]
        }
        // add for the whole string
        string.addAttributes(attributes, range: NSRange(location: 0, length: string.length))
        string.draw(at: NSMakePoint(Self.paddingLeft, y))
    }
}
