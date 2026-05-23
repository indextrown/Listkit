#if canImport(SwiftUI)
import SwiftUI

public struct LKCellState: Equatable, Sendable {
    public let isSelected: Bool
    public let isHighlighted: Bool
    public let isFocused: Bool

    public init(
        isSelected: Bool = false,
        isHighlighted: Bool = false,
        isFocused: Bool = false
    ) {
        self.isSelected = isSelected
        self.isHighlighted = isHighlighted
        self.isFocused = isFocused
    }

    public static let inactive = LKCellState()
}

private struct LKCellStateEnvironmentKey: EnvironmentKey {
    static let defaultValue = LKCellState.inactive
}

public extension EnvironmentValues {
    var lkCellState: LKCellState {
        get { self[LKCellStateEnvironmentKey.self] }
        set { self[LKCellStateEnvironmentKey.self] = newValue }
    }
}
#endif
