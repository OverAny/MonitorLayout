import Foundation

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let autoRestore = "autoRestoreOnMonitorChange"
    }

    var autoRestore: Bool {
        get { defaults.object(forKey: Keys.autoRestore) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoRestore) }
    }
}
