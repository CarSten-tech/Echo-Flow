import Foundation
import AppKit

func test() {
    let systemWide = AXUIElementCreateSystemWide()
    var focused: AnyObject?
    let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
    print("Result: \(result.rawValue)")
    if let element = focused as! AXUIElement? {
        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        print("Role: \(roleValue ?? "nil" as AnyObject)")
    }
}
test()
