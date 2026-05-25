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

private struct LKListKitIndexPathEnvironmentKey: EnvironmentKey {
    static var defaultValue: IndexPath? { nil }
}

private struct LKListKitSectionIDEnvironmentKey: EnvironmentKey {
    static var defaultValue: AnyHashable? { nil }
}

private struct LKListKitItemIDEnvironmentKey: EnvironmentKey {
    static var defaultValue: AnyHashable? { nil }
}

public extension EnvironmentValues {
    var listKitIsSelected: Bool {
        get { lkCellState.isSelected }
        set {
            lkCellState = LKCellState(
                isSelected: newValue,
                isHighlighted: lkCellState.isHighlighted,
                isFocused: lkCellState.isFocused
            )
        }
    }

    var listKitIsHighlighted: Bool {
        get { lkCellState.isHighlighted }
        set {
            lkCellState = LKCellState(
                isSelected: lkCellState.isSelected,
                isHighlighted: newValue,
                isFocused: lkCellState.isFocused
            )
        }
    }

    var listKitIsFocused: Bool {
        get { lkCellState.isFocused }
        set {
            lkCellState = LKCellState(
                isSelected: lkCellState.isSelected,
                isHighlighted: lkCellState.isHighlighted,
                isFocused: newValue
            )
        }
    }

    var listKitIndexPath: IndexPath? {
        get { self[LKListKitIndexPathEnvironmentKey.self] }
        set { self[LKListKitIndexPathEnvironmentKey.self] = newValue }
    }

    var listKitSectionID: AnyHashable? {
        get { self[LKListKitSectionIDEnvironmentKey.self] }
        set { self[LKListKitSectionIDEnvironmentKey.self] = newValue }
    }

    var listKitItemID: AnyHashable? {
        get { self[LKListKitItemIDEnvironmentKey.self] }
        set { self[LKListKitItemIDEnvironmentKey.self] = newValue }
    }
}
#endif
