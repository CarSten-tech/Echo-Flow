import Foundation
import os.log

/// Enterprise-grade structured logging for EchoFlow using native OSLog.
public enum AppLog {
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.echoflow.app"
    
    /// Categories for structured logging
    public enum Category: String {
        case audio = "Audio"
        case routing = "Routing"
        case privacy = "Privacy"
        case inference = "Inference"
        case xpc = "XPC"
        case general = "General"
    }
    
    /// Internal cache of os_log instances per category
    private static var loggers: [Category: OSLog] = [:]
    
    /// Retrieves or creates an OSLog instance for a specific category
    private static func logger(for category: Category) -> OSLog {
        if let existingLogger = loggers[category] {
            return existingLogger
        }
        let newLogger = OSLog(subsystem: subsystem, category: category.rawValue)
        loggers[category] = newLogger
        return newLogger
    }
    
    // MARK: - Convenience Methods
    
    /// Logs a debug message (only visible during debugging, low overhead)
    public static func debug(_ message: String, category: Category = .general) {
        os_log("%{public}@", log: logger(for: category), type: .debug, message)
    }
    
    /// Logs an informational message
    public static func info(_ message: String, category: Category = .general) {
        os_log("%{public}@", log: logger(for: category), type: .info, message)
    }
    
    /// Logs a warning message
    public static func warning(_ message: String, category: Category = .general) {
        os_log("%{public}@", log: logger(for: category), type: .default, message)
    }
    
    /// Logs an error message
    public static func error(_ message: String, category: Category = .general) {
        os_log("%{public}@", log: logger(for: category), type: .error, message)
    }
    
    /// Logs a critical fault (may trigger sysdiagnose on macOS)
    public static func fault(_ message: String, category: Category = .general) {
        os_log("%{public}@", log: logger(for: category), type: .fault, message)
    }
}
