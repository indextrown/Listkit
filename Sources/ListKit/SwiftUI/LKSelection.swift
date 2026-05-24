#if canImport(SwiftUI)
import SwiftUI

public enum LKSelectionMode: Equatable {
    case none
    case single
    case multiple
}

@MainActor
struct LKSelectionConfiguration {
    var mode: LKSelectionMode
    var selectedIDs: @MainActor () -> [AnyHashable]
    var setSelectedIDs: (@MainActor ([AnyHashable]) -> Void)?

    var hasBinding: Bool {
        setSelectedIDs != nil
    }

    init(mode: LKSelectionMode = .single) {
        self.mode = mode
        self.selectedIDs = { [] }
        self.setSelectedIDs = nil
    }

    init<ID: Hashable>(selection: Binding<ID?>) {
        self.mode = .single
        self.selectedIDs = {
            selection.wrappedValue.map { [AnyHashable($0)] } ?? []
        }
        self.setSelectedIDs = { ids in
            selection.wrappedValue = ids.first?.base as? ID
        }
    }

    init<ID: Hashable>(selection: Binding<Set<ID>>) {
        self.mode = .multiple
        self.selectedIDs = {
            selection.wrappedValue.map { AnyHashable($0) }
        }
        self.setSelectedIDs = { ids in
            selection.wrappedValue = Set(ids.compactMap { $0.base as? ID })
        }
    }

    func replacing(mode: LKSelectionMode) -> Self {
        var configuration = self
        configuration.mode = mode
        return configuration
    }
}
#endif
