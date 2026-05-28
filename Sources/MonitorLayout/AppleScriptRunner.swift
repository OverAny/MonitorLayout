import Foundation
import Carbon

enum AppleScriptRunner {
    /// Execute the script and return its descriptor, or nil on error.
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error = error {
            NSLog("AppleScript failed (\(error[NSAppleScript.errorNumber] ?? "?")): \(error[NSAppleScript.errorMessage] ?? "?")")
            return nil
        }
        return result
    }

    static func runString(_ source: String) -> String? {
        run(source)?.stringValue
    }

    static func runList(_ source: String) -> [String]? {
        guard let descriptor = run(source) else { return nil }
        guard descriptor.descriptorType == typeAEList else {
            return descriptor.stringValue.map { [$0] }
        }
        var items: [String] = []
        let count = descriptor.numberOfItems
        if count <= 0 { return [] }
        for i in 1...count {
            if let item = descriptor.atIndex(i)?.stringValue {
                items.append(item)
            }
        }
        return items
    }
}
