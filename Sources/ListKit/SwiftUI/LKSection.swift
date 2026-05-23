#if canImport(SwiftUI)
import SwiftUI

@MainActor
public struct LKSection {
    public let model: LKSectionModel
    public let events: LKSectionEvents
    public let headerEvents: LKSupplementaryEvents
    public let footerEvents: LKSupplementaryEvents
    public let rows: [LKAnyRow]

    public init(
        id: some Hashable,
        @LKRowsBuilder _ rows: () -> [LKAnyRow]
    ) {
        self.init(
            id: id,
            rows: rows(),
            header: nil,
            footer: nil
        )
    }

    public init<Header: View>(
        id: some Hashable,
        @LKRowsBuilder _ rows: () -> [LKAnyRow],
        @ViewBuilder header: @escaping @MainActor () -> Header
    ) {
        self.init(
            id: id,
            rows: rows(),
            header: LKSupplementaryModel(
                id: AnyHashable(id),
                kind: .header,
                makeContent: { AnyView(header()) }
            ),
            footer: nil
        )
    }

    public init<Header: View, Footer: View>(
        id: some Hashable,
        @LKRowsBuilder _ rows: () -> [LKAnyRow],
        @ViewBuilder header: @escaping @MainActor () -> Header,
        @ViewBuilder footer: @escaping @MainActor () -> Footer
    ) {
        self.init(
            id: id,
            rows: rows(),
            header: LKSupplementaryModel(
                id: AnyHashable(id),
                kind: .header,
                makeContent: { AnyView(header()) }
            ),
            footer: LKSupplementaryModel(
                id: AnyHashable(id),
                kind: .footer,
                makeContent: { AnyView(footer()) }
            )
        )
    }

    private init(
        id: some Hashable,
        rows: [LKAnyRow],
        header: LKSupplementaryModel?,
        footer: LKSupplementaryModel?
    ) {
        self.rows = rows
        self.events = LKSectionEvents()
        self.headerEvents = LKSupplementaryEvents()
        self.footerEvents = LKSupplementaryEvents()
        self.model = LKSectionModel(
            id: id,
            items: rows.map(\.model),
            header: header,
            footer: footer
        )
    }
}
#endif
