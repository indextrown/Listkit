#if canImport(SwiftUI)
@resultBuilder
public enum LKListBuilder {
    public static func buildBlock(_ components: [LKSection]...) -> [LKSection] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: LKSection) -> [LKSection] {
        [expression]
    }

    public static func buildOptional(_ component: [LKSection]?) -> [LKSection] {
        component ?? []
    }

    public static func buildEither(first component: [LKSection]) -> [LKSection] {
        component
    }

    public static func buildEither(second component: [LKSection]) -> [LKSection] {
        component
    }

    public static func buildArray(_ components: [[LKSection]]) -> [LKSection] {
        components.flatMap { $0 }
    }
}
#endif
