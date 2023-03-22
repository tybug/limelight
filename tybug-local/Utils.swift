import Foundation
import Cocoa
import SQLite

class Utils: NSObject, NSUserNotificationCenterDelegate {
    static let shared = Utils()

    let eventSource = CGEventSource.init(stateID: .hidSystemState)
    let app = NSApp.delegate as! AppDelegate

    // https://gist.github.com/ericdke/fec20e6db9e0aa25e8ea
    func showNotification(message: String) -> Void {
        let notification = NSUserNotification()
        notification.title = message
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.deliver(notification)
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    func shell(_ command: String) {
        let task = Process()
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.launch()
    }

    // same as `shell`, but blocks and returns the output of the command.
    func shellBlocking(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

        return output
    }

    func runApplescript(_ applescript: NSAppleScript) {
        // run applescript non-blockingly, on a separate thread.
        DispatchQueue.global(qos: .userInitiated).async {
            applescript.executeAndReturnError(nil)
        }
    }

    func setPasteboardContents(_ contents: String) {
        // have to clear before writing anything
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contents, forType: .string)
    }
}


// make working with strings bearable
extension StringProtocol {
    func firstIndexInt(of element: Element) -> Int? {
        let index = firstIndex(of: element)
        if index == nil {
            return nil
        }
        return distance(from: startIndex, to: index!)
    }

    subscript(_ offset: Int) -> Element {
        self[index(startIndex, offsetBy: offset)]
    }
    subscript(_ range: Range<Int>) -> String {
        String(prefix(range.lowerBound + range.count).suffix(range.count))
    }
    subscript(_ range: ClosedRange<Int>) -> String {
        String(prefix(range.lowerBound + range.count).suffix(range.count))
    }
    subscript(_ range: PartialRangeThrough<Int>) -> String {
        String(prefix(range.upperBound.advanced(by: 1)))
    }
    subscript(_ range: PartialRangeUpTo<Int>) -> String {
        String(prefix(range.upperBound))
    }
    subscript(_ range: PartialRangeFrom<Int>) -> String {
        String(suffix(Swift.max(0, count-range.lowerBound)))
    }
}


enum NSCorner {
    case upperLeft
    case upperRight
    case lowerLeft
    case lowerRight
}

extension NSObject {
    func makeRoundedPath(_ rect: NSRect, radius: CGFloat, roundCorners: [NSCorner] = [.upperLeft, .upperRight, .lowerLeft, .lowerRight]) -> NSBezierPath {
        let path = NSBezierPath()
        var center: CGPoint
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        if roundCorners.contains(.upperLeft) {
            // top side
            path.move(to: NSMakePoint(radius, minY))
        } else {
            path.move(to: NSMakePoint(minX, minY))
        }

        if roundCorners.contains(.upperRight) {
            // upper right corner
            path.line(to: NSMakePoint(maxX - radius, minY))
            center = NSMakePoint(maxX - radius,  radius)
            path.appendArc(withCenter: center, radius: radius, startAngle: 270, endAngle: 360)
        } else {
            path.line(to: NSMakePoint(maxX, minY))
        }

        if roundCorners.contains(.lowerRight) {
            // right side
            path.line(to: NSMakePoint(maxX, maxY - radius))

            // lower right corner
            center = NSMakePoint(maxX - radius, maxY - radius)
            path.appendArc(withCenter: center, radius: radius, startAngle: 360, endAngle: 90)
        } else {
            path.line(to: NSMakePoint(maxX, maxY))
        }

        if roundCorners.contains(.lowerLeft) {
            // bottom side
            path.line(to: NSMakePoint(minX + radius, maxY))

            // lower left corner
            center = NSMakePoint(minX + radius, maxY - radius)
            path.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 180)
        } else {
            path.line(to: NSMakePoint(minX, maxY))
        }


        if roundCorners.contains(.upperLeft) {
            // left side
            path.line(to: NSMakePoint(minX, minY + radius))

            // upper left corner
            center = NSMakePoint(minX + radius, minY + radius)
            path.appendArc(withCenter: center, radius: radius, startAngle: 180, endAngle: 270)
        } else {
            path.line(to: NSMakePoint(minX, minY))
        }

        return path
    }
}
