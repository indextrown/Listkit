#if canImport(SwiftUI)
/// Type-erased row used by section builders.
public struct LKAnyRow {
    public let model: LKItemModel
    public let events: LKRowEvents

    public init(model: LKItemModel, events: LKRowEvents = LKRowEvents()) {
        self.model = model
        self.events = events
    }
}
#endif
