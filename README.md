# ListKit

`ListKit` is a SwiftUI-facing list library backed by `UICollectionView`.

The project goal is to keep SwiftUI-style list declaration while exposing the collection view delegate surface that SwiftUI `List` does not provide directly.

## Quick Start

The first example is kept in sync with [BasicListExample](./Examples/ListKitExamples/ListKitExamples.swift):

```swift
import SwiftUI
import ListKit

struct Message: Identifiable, Hashable {
    let id: Int
    var title: String
    var subtitle: String
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.title)
                .font(.headline)
            Text(message.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

enum ImagePipeline {
    static func resume(for id: AnyHashable) {}
    static func pause(for id: AnyHashable) {}
}

struct InboxView: View {
    let messages: [Message]

    var body: some View {
        LKList(messages, id: \.id) { message in
            MessageRow(message: message)
        }
        .listKitStyle(.plain)
        .onSelect { context in
            print("Selected", context.id)
        }
        .onWillDisplay { context in
            ImagePipeline.resume(for: context.id)
        }
        .onDidEndDisplaying { context in
            ImagePipeline.pause(for: context.id)
        }
        .refreshable {
            await reload()
        }
        .updateEngine(.diffableDataSource)
    }

    private func reload() async {}
}
```

Additional previewable examples live in [Examples/ListKitExamples](./Examples/ListKitExamples/ListKitExamples.swift), including section headers and footers, selection, refresh, search, display lifecycle hooks, context menus, grid layout, both update engines, and large data.

## Current Status

Implementation is tracked in [AGENTS.md](./AGENTS.md). The first milestone establishes the package baseline, public `LK` namespace direction, and test command.

## Requirements

- Swift 6.3
- iOS 16.0+
- Swift Package Manager
- DifferenceKit 1.3.0 is currently a direct package dependency for the `.differenceKit` update engine.

## Test

```sh
swift test
```

For UIKit behavior, run the iOS simulator test suite:

```sh
xcodebuild test -scheme ListKit -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4'
```

## Release Status

- Product: one SwiftPM library product, `ListKit`.
- Versioning: semantic versioning starts with the first tag; the draft first release is tracked in [CHANGELOG.md](./CHANGELOG.md).
- License: ListKit is released under the [MIT License](./LICENSE).
- Third-party notices: [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) records the current DifferenceKit attribution.
- DifferenceKit: the dependency is intentionally visible in `Package.swift` for this milestone. Splitting it into an optional product is a pre-1.0 compatibility item.
- Availability: the package declares iOS 16, macCatalyst 16, tvOS 16, and macOS 10.15. UIKit-backed runtime behavior is compiled behind UIKit and SwiftUI availability checks.

## How ListKit Differs From SwiftUI List

`ListKit` keeps the SwiftUI declaration style but renders through `UICollectionView`.

| Area | SwiftUI `List` | `ListKit` |
| --- | --- | --- |
| Row content | SwiftUI `View` | SwiftUI `View` hosted in collection view cells |
| Delegate lifecycle | Mostly hidden | Selection, highlight, display, scroll, prefetch, context menu, focus, menu, and spring loading hooks |
| Update strategy | System controlled | `.reloadData`, `.diffableDataSource`, or `.differenceKit` |
| Layout | SwiftUI list styles | `UICollectionViewCompositionalLayout` backed list and grid layouts |
| Escape hatch | Limited UIKit control | UIKit typed advanced hooks where needed |

Use SwiftUI `List` when system behavior is enough. Use `ListKit` when the screen needs collection view delegate timing, custom update strategy, or collection layout control while keeping SwiftUI row views.

## Delegate Hooks

Common hooks are exposed as typed SwiftUI modifiers:

| UIKit delegate surface | ListKit API |
| --- | --- |
| `shouldSelectItemAt`, `didSelectItemAt` | `.onShouldSelect`, `.onSelect`, `.selection`, `.selectionMode` |
| `shouldDeselectItemAt`, `didDeselectItemAt` | `.onShouldDeselect`, `.onDeselect` |
| `shouldHighlightItemAt`, `didHighlightItemAt`, `didUnhighlightItemAt` | `.onShouldHighlight`, `.onHighlight`, `.onUnhighlight` |
| `willDisplay`, `didEndDisplaying` | `.onWillDisplay`, `.onDidEndDisplaying` |
| supplementary display lifecycle | `.onWillDisplayHeader`, `.onDidEndDisplayingHeader`, `.onWillDisplayFooter`, `.onDidEndDisplayingFooter` |
| `UICollectionViewDataSourcePrefetching` | `.onPrefetch`, `.onCancelPrefetch` |
| primary action | `.onCanPerformPrimaryAction`, `.onPrimaryAction` |
| multiple selection interaction | `.onShouldBeginMultipleSelectionInteraction`, `.onBeginMultipleSelectionInteraction`, `.onEndMultipleSelectionInteraction` |
| context menu delegate | `.uiContextMenuConfiguration`, `.onPreviewCommit`, `.previewForHighlightingContextMenu`, `.previewForDismissingContextMenu` |
| focus delegate | `.onCanFocus`, `.onShouldUpdateFocus`, `.onDidUpdateFocus`, `.preferredFocusedItem` |
| legacy edit menu actions | `.onShouldShowEditMenu`, `.onCanPerformMenuAction`, `.onPerformMenuAction` |
| spring loading | `.onShouldSpringLoad` |
| scroll view delegate | `.onScroll`, `.onWillBeginDragging`, `.onWillEndDragging`, `.onDidEndDragging`, `.onWillBeginDecelerating`, `.onDidEndDecelerating`, `.onShouldScrollToTop`, `.onDidScrollToTop`, `.onReachEnd` |

Row-level handlers override section-level handlers, and section-level handlers override list-level handlers for the same event.

## Identity And Equality

Every section and row needs a stable identity. For data-driven lists, pass an `id` key path:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
```

For builder lists, `LKSection(id:)` and `LKRow(_:id:)` provide those identities explicitly:

```swift
LKList {
    LKSection(id: "inbox") {
        for message in messages {
            LKRow(message, id: \.id) {
                MessageRow(message: message)
            }
            .equatableToken(message.updatedAt)
        }
    }
}
```

Identity answers “is this the same item?” Equality tokens answer “did the rendered content change?” ListKit does not compare SwiftUI view values. If content can change while identity remains the same, provide `.equatableToken(...)` so update engines can reload or reconfigure the row deliberately.

Avoid storing `IndexPath` for later asynchronous use. Delegate contexts include `id`, `item`, `indexPath`, and `sectionID`; use stable IDs for long-running work.

## Update Engines

Choose an update engine per list:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
.updateEngine(.diffableDataSource)
```

| Engine | Use when | Notes |
| --- | --- | --- |
| `.reloadData` | Debugging, simplest behavior, or when animation is unnecessary | Least sensitive to identity mistakes, but no fine-grained animations |
| `.diffableDataSource` | Default choice for Apple-native diffing | Good fit for stable section and item IDs; content-only changes use reload/reconfigure policy |
| `.differenceKit` | You need staged changesets and explicit content equality | Uses DifferenceKit and relies on stable identity plus useful equality tokens |

If a diff path cannot safely apply an update, ListKit falls back to a safer reload path and can emit a diagnostics warning when diagnostics are enabled.

## Selection And Primary Action

Selection is state. Primary action is intent.

Use selection APIs when the UI should remember selected rows:

```swift
@State private var selection = Set<Message.ID>()

LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
.selection($selection)
.selectionMode(.multiple)
.onShouldSelect { context in
    guard let message = context.item as? Message else { return true }
    return !message.isArchived
}
```

Use primary action when activation should perform work without being treated as selection state. Keyboard, pointer, remote, or accessibility activation can route through primary action:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
.onCanPerformPrimaryAction { _ in true }
.onPrimaryAction { context in
    openMessage(id: context.id)
}
```

## Dynamic Height And Self-Sizing

Rows are hosted SwiftUI views. Prefer normal SwiftUI layout that can produce an intrinsic height, and avoid hard-coded collection view cell heights unless the layout really needs them. ListKit records preferred fitting sizes from hosted cells and supplementary views so later layout invalidation can reuse measured size context.

For large dynamic rows:

- Keep row identity stable while the row expands or collapses.
- Provide an equality token for state that changes row size.
- Prefer estimated list layouts over fixed-size grid cells when text can wrap.
- Keep expensive image work behind display lifecycle or prefetch hooks.

## Refresh And Search

ListKit provides a collection-view-backed refresh control:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
.refreshable {
    await reload()
}
```

Search composes with SwiftUI's native `.searchable`:

```swift
@State private var query = ""

LKList(filteredMessages, id: \.id) { message in
    MessageRow(message: message)
}
.searchable(text: $query)
```

Keep filtering in your view model or computed state, then pass the filtered collection into `LKList`.

## Context Menus

Use SwiftUI's native `.contextMenu` inside row content for simple menus:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
        .contextMenu {
            Button("Archive") {
                archive(message.id)
            }
        }
}
```

Use ListKit's advanced UIKit hooks when the collection view delegate surface is required, such as preview controllers, targeted previews, or preview commit animation:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
.uiContextMenuConfiguration { context, point in
    UIContextMenuConfiguration(identifier: "\(context.id)" as NSString) {
        MessagePreviewController(id: context.id)
    }
}
.onPreviewCommit { configuration, animator in
    // Handle UIKit preview commit animation.
}
```

## Diagnostics

Diagnostics are opt-in at runtime:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
.listKitDiagnostics(.enabled)
.onListKitWarning { warning in
    print("ListKit warning:", warning)
}
```

In debug builds, invalid model identity such as duplicate section or item IDs still triggers assertions early. Runtime diagnostics are for recoverable conditions and release fallback paths, including invalid lookups, unsupported layout values that ListKit can clamp, and diff update fallbacks.

## Performance Troubleshooting

- Use stable IDs. Changing IDs forces removal and insertion instead of an in-place update.
- Add `.equatableToken(...)` for content or size changes that should trigger reconfiguration.
- Start image or video work from `.onWillDisplay`, cancel or pause it from `.onDidEndDisplaying`, and use `.onPrefetch` for near-future work.
- Use `.diffableDataSource` for most animated updates; use `.reloadData` to isolate whether an issue is diffing-related.
- Enable `.listKitDiagnostics(.enabled)` while debugging invalid lookups, unsupported layout values, or diff fallbacks.
- Keep row bodies lightweight. Heavy work should live outside the SwiftUI row body and be keyed by item ID.

## Migrating From SwiftUI List

Start with the same data shape:

```swift
List(messages) { message in
    MessageRow(message: message)
}
```

becomes:

```swift
LKList(messages, id: \.id) { message in
    MessageRow(message: message)
}
```

Then move behavior one concern at a time:

| SwiftUI List concept | ListKit equivalent |
| --- | --- |
| `List(data) { row }` | `LKList(data, id: \.id) { row }` |
| `Section` | `LKSection(id:)` with `header` and `footer` builders |
| `.refreshable` | `.refreshable` on `LKList` |
| `.searchable` | SwiftUI `.searchable` composed on `LKList` |
| `.onDelete`, `.onMove` | Update your source data and let the selected update engine apply the new model |
| simple row `.contextMenu` | Keep SwiftUI `.contextMenu` inside row content |
| UIKit-specific context menu previews | Use ListKit advanced context menu hooks |
| list style | `.listKitStyle(...)` or section `.sectionLayout(...)` |

After the basic migration compiles, choose an update engine, add selection binding if needed, and add delegate hooks only for the lifecycle events the screen actually uses.
