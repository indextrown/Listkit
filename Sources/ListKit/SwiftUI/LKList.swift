#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct LKList<Content: View>: View {
    let model: LKListModel
    let events: LKListEvents
    let sections: [LKSection]

    @ViewBuilder
    public var body: some View {
        #if canImport(UIKit)
        LKCollectionViewRepresentable(model: model)
        #else
        EmptyView()
        #endif
    }

    public init<Data, ID>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> Content
    )
    where
        Data: RandomAccessCollection,
        ID: Hashable
    {
        let items = data.map { element in
            LKItemModel(
                id: element[keyPath: id],
                makeContent: { AnyView(rowContent(element)) }
            )
        }
        self.model = LKListModel(
            sections: [
                LKSectionModel(id: "ListKit.default-section", items: Array(items)),
            ]
        )
        self.events = LKListEvents()
        self.sections = []
    }

    public init(@LKListBuilder content: () -> [LKSection]) where Content == EmptyView {
        let sections = content()
        self.sections = sections
        self.model = LKListModel(sections: sections.map(\.model))
        self.events = LKListEvents()
    }
}
#endif
