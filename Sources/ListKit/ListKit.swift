import Foundation

/// Public namespace marker for the ListKit module.
///
/// The user-facing API uses the `LK` prefix for concrete list types such as
/// `LKList`, `LKSection`, and `LKRow`.
public enum ListKit {
    public static let apiPrefix = "LK"
    public static let minimumIOSVersion = "16.0"
}

/// Update strategy requested by `LKList`.
///
/// The concrete implementations are introduced in later milestones. Keeping
/// this enum available from the first package step fixes the public namespace
/// and gives tests a real public symbol to compile against.
public enum LKUpdateEngine: Sendable, Equatable {
    case reloadData
    case diffableDataSource
    case differenceKit
}

/// Platform capability flags used by tests and documentation.
public enum LKPlatformSupport: Sendable {
    public static var canImportSwiftUI: Bool {
        #if canImport(SwiftUI)
        true
        #else
        false
        #endif
    }

    public static var canImportUIKit: Bool {
        #if canImport(UIKit)
        true
        #else
        false
        #endif
    }
}
