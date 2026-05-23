#if canImport(SwiftUI)
import SwiftUI

@resultBuilder
public enum LKRowsBuilder {
    public static func buildBlock(_ components: [LKAnyRow]...) -> [LKAnyRow] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: LKAnyRow) -> [LKAnyRow] {
        [expression]
    }

    public static func buildExpression<Item, Content>(_ expression: LKRow<Item, Content>) -> [LKAnyRow] {
        [expression.eraseToAnyRow()]
    }

    public static func buildOptional(_ component: [LKAnyRow]?) -> [LKAnyRow] {
        component ?? []
    }

    public static func buildEither(first component: [LKAnyRow]) -> [LKAnyRow] {
        component
    }

    public static func buildEither(second component: [LKAnyRow]) -> [LKAnyRow] {
        component
    }

    public static func buildArray(_ components: [[LKAnyRow]]) -> [LKAnyRow] {
        components.flatMap { $0 }
    }
}
#endif
