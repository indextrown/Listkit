#if canImport(SwiftUI)
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct LKRefreshConfiguration {
    var action: (@MainActor () async -> Void)?
    #if canImport(UIKit)
    var tintColor: UIColor?
    #endif

    var isEnabled: Bool {
        action != nil
    }

    init() {}
}
#endif
