#if canImport(SwiftUI)
import SwiftUI

public struct LKList<Content: View>: View {
    let model: LKListModel
    let events: LKListEvents
    let sections: [LKSection]

    public var body: some View {
        EmptyView()
    }

    public init<Data, ID>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent: @escaping (Data.Element) -> Content
    )
    where
        Data: RandomAccessCollection,
        ID: Hashable
    {
        let items = data.map {
            LKItemModel(id: $0[keyPath: id])
        }
        self.model = LKListModel(
            sections: [
                LKSectionModel(id: "ListKit.default-section", items: Array(items)),
            ]
        )
        self.events = LKListEvents()
        self.sections = []
        _ = data.map(rowContent)
    }

    public init(@LKListBuilder content: () -> [LKSection]) where Content == EmptyView {
        let sections = content()
        self.sections = sections
        self.model = LKListModel(sections: sections.map(\.model))
        self.events = LKListEvents()
    }
}
#endif
