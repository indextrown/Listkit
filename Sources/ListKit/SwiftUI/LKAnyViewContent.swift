#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LKAnyViewContent {
    private let box: any LKAnyViewContentBox

    init<Content: View>(@ViewBuilder _ makeContent: @escaping @MainActor () -> Content) {
        self.box = LKViewContentBox(makeContent: makeContent)
    }

    #if canImport(UIKit)
    @MainActor
    func makeCellContentConfiguration(
        state: LKCellState,
        indexPath: IndexPath?,
        sectionID: AnyHashable?,
        itemID: AnyHashable
    ) -> any UIContentConfiguration {
        box.makeCellContentConfiguration(
            state: state,
            indexPath: indexPath,
            sectionID: sectionID,
            itemID: itemID
        )
    }

    @MainActor
    func makeSupplementaryContentView(state: LKCellState) -> UIView {
        box.makeSupplementaryContentView(state: state)
    }
    #endif
}

private protocol LKAnyViewContentBox {
    #if canImport(UIKit)
    @MainActor
    func makeCellContentConfiguration(
        state: LKCellState,
        indexPath: IndexPath?,
        sectionID: AnyHashable?,
        itemID: AnyHashable
    ) -> any UIContentConfiguration

    @MainActor
    func makeSupplementaryContentView(state: LKCellState) -> UIView
    #endif
}

private struct LKViewContentBox<Content: View>: LKAnyViewContentBox {
    let makeContent: @MainActor () -> Content

    #if canImport(UIKit)
    @MainActor
    func makeCellContentConfiguration(
        state: LKCellState,
        indexPath: IndexPath?,
        sectionID: AnyHashable?,
        itemID: AnyHashable
    ) -> any UIContentConfiguration {
        UIHostingConfiguration {
            makeContent()
                .environment(\.lkCellState, state)
                .environment(\.listKitIndexPath, indexPath)
                .environment(\.listKitSectionID, sectionID)
                .environment(\.listKitItemID, itemID)
        }
    }

    @MainActor
    func makeSupplementaryContentView(state: LKCellState) -> UIView {
        UIHostingConfiguration {
            makeContent()
                .environment(\.lkCellState, state)
        }.makeContentView()
    }
    #endif
}
#endif
