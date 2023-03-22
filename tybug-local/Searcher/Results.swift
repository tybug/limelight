import Foundation
import Cocoa

class MathResultView: SearcherResultView {
    init(_ val: Decimal) {

        let formatter = NumberFormatter()
        // TODO switch to scientific notation for extremely large/small numbers,
        // check spotlight behavior for cutoffs
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10

        let displayValue = formatter.string(from: val as NSNumber)!
        super.init(displayValue)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class FileResultView: SearcherResultView {

    static let resizeVSCodeApplescript = NSAppleScript(source:
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

        tell application "System Events" to ¬
            tell process "Code" to ¬
                tell window 1
                    # setting bounds (`set bounds to {dockWidth, 0, bottomRightX - dockWidth, bottomRightY}`)
                    # doesn't work here for whatever reason, so set position and size independently.
                    set position to {dockWidth + adjustmentPixels, 0}
                    set size to {bottomRightX - dockWidth - adjustmentPixels, bottomRightY}
                end tell
        """
    )!

    var name: String
    var dir: String
    override var closeOnSelected: Bool {
        get { return true }
    }

    init(_ name: String, _ dir: String) {
        self.name = name
        self.dir = dir

        super.init(name)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func onSelected(_ modifierFlags: NSEvent.ModifierFlags) -> SearcherCommandWidget? {
        if modifierFlags.contains(.command) {
            openInFinder()
        } else if modifierFlags.contains(.shift) {
            openInVSCode()
        }  else {
            open()
        }
        return nil
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(dir + "/" + name, inFileViewerRootedAtPath: dir)
    }

    private func openInVSCode() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code", dir + "/" + name]
        task.launch()

        // vscode opens new windows in this weird very small resolution by default, so resize to full size.
        // fine-tuned delay to account for vscode taking some time to launch a new window. Might require more tuning.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            Self.resizeVSCodeApplescript.executeAndReturnError(nil)
        }
    }

    private func open() {
        let url = URL(fileURLWithPath: dir + "/" + name)

        // opening applications can take a while (eg try MusicBrainz Picard), avoid blocking while it opens
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }
}


class CommandResultView: SearcherResultView {
    let command: SearcherCommand
    override var closeOnSelected: Bool {
        get { return true }
    }

    init(command: SearcherCommand) {
        self.command = command
        super.init(command.name)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func onSelected(_ modifierFlags: NSEvent.ModifierFlags) -> SearcherCommandWidget? {
        return command.run()
    }
}
