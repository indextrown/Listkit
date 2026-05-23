# AGENTS.md

## 목적

이 저장소는 SwiftUI에서 `List`처럼 선언적으로 사용할 수 있으면서도, 내부 구현은 `UICollectionView` 기반으로 직접 제어 가능한 `ListKit` 라이브러리를 담습니다.

SwiftUI의 기본 `List`는 `refreshable`, `searchable`, `listStyle`, `swipeActions`, `onMove`, `onDelete` 같은 SwiftUI 친화 API를 제공하지만, `UICollectionViewDelegate`, `UICollectionViewDataSourcePrefetching`, `UICollectionViewDragDelegate`, `UICollectionViewDropDelegate`, `UIScrollViewDelegate`가 가진 세밀한 생명주기와 상호작용 지점을 모두 노출하지 않습니다.

`ListKit`의 목표는 SwiftUI 사용 경험을 유지하면서도 UIKit 컬렉션 뷰의 delegate 제어권을 라이브러리 사용자에게 선택적으로 제공하는 것입니다.

이 문서는 사람과 에이전트가 `ListKit`을 0부터 100까지 설계, 구현, 리뷰, 문서화할 때 따라야 할 상세 명세입니다.

## 한 줄 정의

`ListKit`은 "SwiftUI 문법으로 쓰는 UICollectionView 기반 고급 List"입니다.

## 핵심 문제

SwiftUI `List`는 다음 장점이 있습니다.

- 선언형 데이터 구성
- SwiftUI `View` 기반 셀 작성
- `refreshable`, `searchable`, `listStyle` 같은 시스템 API 통합
- 상태 변경에 따른 자동 갱신
- Navigation, EditMode, swipe action 등 SwiftUI 생태계와의 자연스러운 연결

하지만 다음 제약이 있습니다.

- 특정 셀의 선택 가능 여부를 동적으로 막기 어렵습니다.
- 선택과 primary action을 명확히 분리하기 어렵습니다.
- highlight, unhighlight 생명주기를 세밀하게 받기 어렵습니다.
- `willDisplay`, `didEndDisplaying`을 cell, header, footer 단위로 안정적으로 받기 어렵습니다.
- context menu preview, targeted preview, commit animator를 UIKit 수준으로 제어하기 어렵습니다.
- focus, keyboard, tvOS, pointer, multi-selection interaction 제어가 제한적입니다.
- old style menu action, spring loading, drag/drop, prefetching 같은 collection view 기능을 온전히 쓰기 어렵습니다.
- 대규모 데이터에서 update 전략과 diffing 엔진을 명시적으로 고르기 어렵습니다.

`ListKit`은 이 제약을 해결하기 위해 SwiftUI `View`를 `UIHostingController` 또는 `UIHostingConfiguration` 경로로 셀에 호스팅하고, 전체 리스트는 `UICollectionView`를 `UIViewRepresentable`로 감싸 구현합니다.

## 제품 방향성

지향:

- SwiftUI에서 자연스러운 선언형 API
- UIKit delegate 기능을 숨기지 않는 명확한 escape hatch
- `UICollectionViewDiffableDataSource`와 `DifferenceKit` 중 선택 가능한 update engine
- iOS 앱에서 실사용 가능한 성능과 안정성
- 셀 재사용, hosting, sizing, diffing, selection을 라이브러리 내부에서 일관되게 처리
- public API는 작게 유지하되 delegate surface는 빠짐없이 확장 가능

지양:

- SwiftUI `List`를 완전히 복제한다고 과장하는 문서
- UIKit delegate를 전부 modifier로만 감싸 public API를 폭발시키는 설계
- 복잡한 generic nesting이 사용 예시의 중심이 되는 구조
- 모든 기능을 첫 버전에 한 번에 넣는 방식
- diffing, layout, event routing이 서로 강하게 결합된 내부 구조
- 셀 identity와 content equality가 불분명한 API

## 최소 플랫폼과 패키지 기준

권장 기준:

- Swift: 6.x
- Swift Package Manager 기반
- iOS: 16.0 이상 권장
- macCatalyst: 구조상 가능하게 설계하되 1차 목표는 iOS
- tvOS: focus 관련 API를 고려하되 1차 릴리즈 필수 대상은 아님

iOS 16 이상을 권장하는 이유:

- `UIHostingConfiguration` 사용 가능
- SwiftUI hosting cell 구현 비용 감소
- compositional layout, diffable data source, modern collection view API와 궁합이 좋음

단, `UIHostingController` 기반 fallback을 내부 전략으로 둘 수 있습니다. fallback을 제공할 경우 public API가 둘로 갈라지지 않아야 합니다.

## 최상위 사용 예시

최종 사용 경험은 아래 형태를 목표로 합니다.

```swift
import SwiftUI
import ListKit

struct InboxView: View {
    @State private var messages: [Message] = []
    @State private var query = ""
    @State private var selection = Set<Message.ID>()

    var body: some View {
        LKList(messages, id: \.id) { message in
            MessageRow(message: message)
        }
        .listKitStyle(.plain)
        .selection($selection)
        .refreshable {
            await reload()
        }
        .searchable(text: $query)
        .onShouldSelect { context in
            !context.item.isArchived
        }
        .onSelect { context in
            open(message: context.item)
        }
        .onHighlight { context in
            highlight(messageID: context.id)
        }
        .onUnhighlight { context in
            unhighlight(messageID: context.id)
        }
        .onWillDisplay { context in
            imagePipeline.resume(for: context.id)
        }
        .onDidEndDisplaying { context in
            imagePipeline.pause(for: context.id)
        }
        .updateEngine(.diffableDataSource)
    }
}
```

섹션이 필요한 화면은 아래 형태를 목표로 합니다.

```swift
LKList {
    LKSection(id: "pinned") {
        for item in pinnedItems {
            LKRow(item, id: \.id) {
                PinnedRow(item: item)
            }
        }
    } header: {
        Text("Pinned")
    }

    LKSection(id: "all") {
        for item in items {
            LKRow(item, id: \.id) {
                MessageRow(message: item)
            }
            .onSelect { context in
                open(message: context.item)
            }
        }
    } header: {
        Text("All")
    } footer: {
        Text("\(items.count) messages")
    }
}
.sectionLayout(.list)
.updateEngine(.differenceKit)
```

## 핵심 타입

### `LKList`

SwiftUI에서 노출되는 최상위 list view입니다.

역할:

- `UICollectionView`를 `UIViewRepresentable`로 감쌉니다.
- SwiftUI data와 modifiers를 내부 `ListModel`로 변환합니다.
- coordinator를 통해 UIKit delegate/data source 이벤트를 SwiftUI closure로 라우팅합니다.
- update engine을 선택하고 변경 사항을 collection view에 반영합니다.

공개 방향:

```swift
public struct LKList<Content: View>: View {
    public var body: some View { get }
}
```

데이터 기반 initializer:

```swift
public init<Data, ID, RowContent>(
    _ data: Data,
    id: KeyPath<Data.Element, ID>,
    @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
)
where Data: RandomAccessCollection, ID: Hashable, RowContent: View
```

builder 기반 initializer:

```swift
public init(@LKListBuilder content: () -> [LKSectionModel])
```

### `LKSection`

섹션 단위 모델을 구성하는 SwiftUI DSL 타입입니다.

역할:

- section identity 소유
- row 배열 소유
- header/footer/supplementary view 소유
- section layout override 소유
- section-level delegate handlers 소유

필수 속성:

- `id: AnyHashable`
- `items: [LKItemModel]`
- `header: LKSupplementaryModel?`
- `footer: LKSupplementaryModel?`
- `layout: LKSectionLayout?`
- `events: LKSectionEvents`

### `LKRow`

아이템 단위 모델입니다.

역할:

- item identity 소유
- SwiftUI content view factory 소유
- selection/highlight/menu/focus/display 이벤트 override 소유
- diffing에 필요한 identity/equality metadata 제공

필수 속성:

- `id: AnyHashable`
- `base: Any?`
- `content: AnyViewFactory`
- `equatableToken: AnyHashable?`
- `events: LKRowEvents`
- `configuration: LKRowConfiguration`

### `LKContext`

모든 delegate callback에 전달되는 공통 context입니다.

권장 형태:

```swift
public struct LKItemContext<Item> {
    public let item: Item
    public let id: AnyHashable
    public let indexPath: IndexPath
    public let sectionID: AnyHashable
}
```

타입 소거 경로:

```swift
public struct LKAnyItemContext {
    public let id: AnyHashable
    public let item: Any
    public let indexPath: IndexPath
    public let sectionID: AnyHashable
}
```

내부 delegate 라우팅은 항상 최신 snapshot 기준으로 `indexPath -> model`을 해석해야 합니다. 오래된 `indexPath`를 비동기 closure 안에 저장해 나중에 쓰는 패턴을 권장하지 않습니다.

### `LKUpdateEngine`

데이터 갱신 엔진 선택지입니다.

```swift
public enum LKUpdateEngine {
    case diffableDataSource
    case differenceKit
    case reloadData
}
```

목표:

- Apple `UICollectionViewDiffableDataSource` 사용 가능
- `DifferenceKit` 사용 가능
- 디버깅 또는 회피 경로로 `reloadData` 사용 가능

`DifferenceKit`은 외부 dependency가 필요하므로 별도 target/product로 분리하는 것을 우선 검토합니다.

권장 패키지 구조:

- `ListKitCore`: 모델, 이벤트, 공통 타입
- `ListKit`: SwiftUI public API와 UIKit bridge
- `ListKitDifferenceKit`: DifferenceKit update engine adapter
- `ListKitTests`: core 테스트
- `ListKitUIKitTests`: 가능하면 UIKit 동작 테스트

현재 저장소가 작은 초기 상태라면 1차 구현은 단일 target으로 시작해도 됩니다. 다만 `DifferenceKit` dependency는 처음부터 core와 분리 가능한 구조로 설계해야 합니다.

## 전체 아키텍처

흐름:

`SwiftUI View -> LKList modifiers -> ListModel -> UIViewRepresentable -> Coordinator -> UICollectionView -> Cell Hosting -> Delegate Router -> SwiftUI closures`

레이어:

1. SwiftUI API Layer
   - `LKList`
   - `LKSection`
   - `LKRow`
   - modifiers
   - result builders

2. Model Layer
   - `LKListModel`
   - `LKSectionModel`
   - `LKItemModel`
   - `LKSupplementaryModel`
   - event containers
   - layout descriptors

3. Bridge Layer
   - `LKCollectionViewRepresentable`
   - `Coordinator`
   - collection view creation/update
   - environment propagation

4. Adapter Layer
   - data source adapter
   - delegate adapter
   - update engine adapter
   - cell/supplementary registration

5. Hosting Layer
   - `UIHostingConfiguration` path
   - `UIHostingController` fallback path
   - sizing invalidation
   - reuse handling

6. Diagnostics Layer
   - duplicate ID detection
   - invalid section/item lookup logging
   - diff failure fallback
   - main thread assertions

## Adapter 설계

`ListKit`은 `UICollectionView`에 대한 직접 제어를 `Adapter` 계층에 모읍니다.

KarrotListKit의 `CollectionViewAdapter`는 다음 방식을 사용합니다.

- adapter가 `UICollectionViewDelegate`, `UICollectionViewDataSource`, `UICollectionViewDataSourcePrefetching`을 직접 담당합니다.
- 현재 `List` snapshot을 adapter가 보관합니다.
- cell/header/footer view instance는 보관하지 않습니다.
- 대신 등록된 reuse identifier를 `Set<String>`으로 보관합니다.
- 새 list를 apply할 때 section을 순회하며 아직 등록되지 않은 cell/header/footer reuse identifier만 collection view에 register합니다.
- header/footer/cell size는 view instance가 아니라 별도 size storage dictionary에 저장합니다.

이 방향은 `ListKit`에도 맞습니다. 1차 구현에서는 별도 registry 타입을 만들지 않고 adapter가 header, footer, cell 등록 상태를 각각 `Set`으로 직접 관리합니다.

권장 내부 구조:

```swift
@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?
    private var currentModel: LKListModel?

    private var registeredCellKeys = Set<LKCellRegistrationKey>()
    private var registeredHeaderKeys = Set<LKSupplementaryRegistrationKey>()
    private var registeredFooterKeys = Set<LKSupplementaryRegistrationKey>()

    private var isUpdating = false
    private var queuedUpdate: LKQueuedUpdate?

    private let delegateRouter: LKDelegateRouter
    private let updateCoordinator: LKUpdateCoordinator
    private let sizeStorage: LKComponentSizeStorage
}
```

핵심 원칙:

- adapter는 cell/header/footer 인스턴스를 보관하지 않습니다.
- adapter는 cell/header/footer registration 상태를 보관합니다.
- adapter는 현재 `LKListModel` snapshot을 보관합니다.
- adapter는 `indexPath -> section/item/supplementary` lookup을 제공합니다.
- adapter는 delegate callback을 직접 처리하거나 `LKDelegateRouter`로 위임합니다.
- adapter는 update 중 들어온 apply 요청을 queueing 합니다.

### Registration Set

KarrotListKit은 아래처럼 세 개의 set을 둡니다.

```swift
private var registeredCellReuseIdentifiers = Set<String>()
private var registeredHeaderReuseIdentifiers = Set<String>()
private var registeredFooterReuseIdentifiers = Set<String>()
```

`ListKit`은 이 아이디어를 유지하되, key를 reuse identifier 문자열 하나로만 두지 않습니다. SwiftUI hosting 전략과 supplementary kind가 registration에 영향을 주기 때문입니다.

권장 key:

```swift
struct LKCellRegistrationKey: Hashable {
    let reuseIdentifier: String
    let hostingStrategy: LKHostingStrategy
}

struct LKSupplementaryRegistrationKey: Hashable {
    let kind: String
    let reuseIdentifier: String
    let hostingStrategy: LKHostingStrategy
}
```

권장 adapter 직접 관리:

```swift
@MainActor
final class LKCollectionViewAdapter: NSObject {
    private weak var collectionView: UICollectionView?

    private var registeredCellKeys = Set<LKCellRegistrationKey>()
    private var registeredHeaderKeys = Set<LKSupplementaryRegistrationKey>()
    private var registeredFooterKeys = Set<LKSupplementaryRegistrationKey>()

    private func registerReuseIdentifiersIfNeeded(from model: LKListModel) {
        guard let collectionView else { return }

        for section in model.sections {
            for item in section.items {
                registerCellIfNeeded(item)
            }

            if let header = section.header {
                registerHeaderIfNeeded(header)
            }

            if let footer = section.footer {
                registerFooterIfNeeded(footer)
            }
        }
    }

    private func registerCellIfNeeded(_ item: LKItemModel) {
        guard let collectionView else { return }

        let key = LKCellRegistrationKey(
            reuseIdentifier: item.reuseIdentifier,
            hostingStrategy: item.hostingStrategy
        )

        guard registeredCellKeys.insert(key).inserted else { return }

        collectionView.register(
            LKHostingCollectionViewCell.self,
            forCellWithReuseIdentifier: key.reuseIdentifier
        )
    }

    private func registerHeaderIfNeeded(_ header: LKSupplementaryModel) {
        guard let collectionView else { return }

        let key = LKSupplementaryRegistrationKey(
            kind: UICollectionView.elementKindSectionHeader,
            reuseIdentifier: header.reuseIdentifier,
            hostingStrategy: header.hostingStrategy
        )

        guard registeredHeaderKeys.insert(key).inserted else { return }

        collectionView.register(
            LKHostingSupplementaryView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: key.reuseIdentifier
        )
    }

    private func registerFooterIfNeeded(_ footer: LKSupplementaryModel) {
        guard let collectionView else { return }

        let key = LKSupplementaryRegistrationKey(
            kind: UICollectionView.elementKindSectionFooter,
            reuseIdentifier: footer.reuseIdentifier,
            hostingStrategy: footer.hostingStrategy
        )

        guard registeredFooterKeys.insert(key).inserted else { return }

        collectionView.register(
            LKHostingSupplementaryView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: key.reuseIdentifier
        )
    }
}
```

cell/header/footer를 각각 별도 set으로 관리하는 이유:

- cell과 supplementary registration API가 다릅니다.
- header와 footer는 같은 reuse identifier를 쓸 수 있어도 element kind가 다릅니다.
- debug 로그와 테스트에서 어떤 영역이 등록됐는지 분리해서 확인하기 쉽습니다.
- 나중에 custom supplementary kind를 추가할 때 footer/header 정책과 섞이지 않습니다.

1차 구현에서는 adapter 직접 set 관리가 기본입니다. 다음 조건이 생기면 registry 추출을 검토합니다.

- custom supplementary kind가 늘어납니다.
- diffable `UICollectionView.CellRegistration` / `UICollectionView.SupplementaryRegistration` 객체를 저장해야 합니다.
- hosting strategy별 registration 정책이 복잡해집니다.
- registration 정책만 독립 테스트해야 합니다.

그때는 아래처럼 class store로 추출합니다.

```swift
@MainActor
final class LKRegistrationStore {
    private var registeredKeys = Set<LKRegistrationKey>()
    private var boxesByKey: [LKRegistrationKey: LKAnyRegistrationBox] = [:]
}
```

타입 기준:

- 1차 registration state: adapter 내부 `Set`
- 추출 이후 `RegistrationStore`: `final class`
- `ComponentSizeStorage`: `final class`
- `Adapter`, `Coordinator`, `Router`, `UpdateCoordinator`: `final class`
- `RegistrationKey`, `SizeContext`, `ListModel`, `SectionModel`, `ItemModel`: `struct`

1차 구현에서는 classical `register(_:forCellWithReuseIdentifier:)` 경로가 단순하고, diffable data source와 DifferenceKit 양쪽에서 공유하기 쉽습니다. `CellRegistration` API는 별도 최적화 milestone에서 검토합니다.

### Header/Footer/Cell 보관 정책

보관해야 하는 것:

- 현재 list model snapshot
- cell registration key set
- supplementary registration key set
- size cache
- prefetch operation cache
- queued update
- selection/focus restoration metadata

보관하지 말아야 하는 것:

- `UICollectionViewCell` 인스턴스 배열
- `UICollectionReusableView` 인스턴스 배열
- visible cell에 대한 strong reference
- indexPath를 장기 key로 쓰는 영구 상태

이 정책의 이유:

- cell과 supplementary view instance 생명주기는 collection view reuse system이 소유합니다.
- adapter가 view instance를 오래 보관하면 reuse, memory, stale SwiftUI state 문제가 생깁니다.
- SwiftUI row/header/footer content는 model snapshot과 hosting render 단계에서 다시 구성되어야 합니다.
- 장기 식별자는 `IndexPath`가 아니라 section id / item id여야 합니다.

### Size Storage

KarrotListKit은 cell/header/footer size를 별도 dictionary에 저장합니다.

```swift
cellSizeStore: [AnyHashable: SizeContext]
headerSizeStore: [AnyHashable: SizeContext]
footerSizeStore: [AnyHashable: SizeContext]
```

`ListKit`도 이 구조를 채택합니다.

권장 key:

- cell size: item id
- header size: section id + header kind
- footer size: section id + footer kind
- custom supplementary size: section id + supplementary kind + supplementary id

권장 value:

```swift
struct LKSizeContext {
    let size: CGSize
    let contentToken: AnyHashable?
}
```

`contentToken`이 이전과 같을 때만 cached size를 신뢰합니다. SwiftUI view 자체를 equality 비교 대상으로 삼지 않습니다.

### Apply 시 등록 순서

`apply(_:)`는 다음 순서로 동작합니다.

1. main actor 확인
2. update 중이면 마지막 update만 queue에 저장
3. 새 model의 duplicate id 검사
4. 새 model을 순회하며 필요한 cell/header/footer registration 선등록
5. update engine에 model 전달
6. update engine이 collection view 갱신
7. current snapshot 교체
8. selection/focus 복원
9. queued update가 있으면 이어서 apply

registration은 diff 적용 전에 끝나야 합니다. diff가 insert할 cell이나 supplementary view를 collection view가 곧바로 dequeue할 수 있어야 하기 때문입니다.

## 내부 모델 원칙

Identity:

- section id와 item id는 반드시 stable 해야 합니다.
- 같은 section 안에서 item id가 중복되면 debug build에서 assertion을 발생시킵니다.
- 전체 list에서 item id 전역 중복을 허용할지 여부는 update engine별 요구에 맞춰 결정합니다.
- diffable data source는 section/item identifier를 `Hashable`로 안정적으로 표현해야 합니다.

Equality:

- identity는 "같은 항목인가"를 판단합니다.
- equality token은 "내용이 바뀌었는가"를 판단합니다.
- row content 전체 SwiftUI view를 equality 비교 대상으로 삼지 않습니다.
- 사용자가 명시적으로 `equatableToken`을 제공하지 않으면 identity 기반 reload 최소화만 보장합니다.

Index path:

- delegate callback 시점에는 `indexPath`가 유효하다고 가정할 수 있습니다.
- async 작업에 indexPath를 넘기는 public 예시는 피합니다.
- public context에는 가능하면 item id와 item 값을 함께 제공합니다.

Snapshot:

- coordinator는 최신 `LKListModel` snapshot을 소유합니다.
- UIKit callback은 항상 coordinator의 현재 snapshot을 조회합니다.
- update 중 들어온 새 SwiftUI update는 직렬화해야 합니다.

## Cell Hosting 전략

1차 전략:

- iOS 16 이상에서는 `UIHostingConfiguration`을 기본 사용합니다.
- 셀 content는 `UICollectionViewCell.contentConfiguration`에 설정합니다.
- SwiftUI environment가 바뀌면 configuration을 갱신합니다.

fallback 전략:

- `UIHostingController`를 셀 contentView에 embed합니다.
- reuse 시 rootView를 교체하고 기존 hosting controller를 재사용합니다.
- child view controller containment가 필요하면 representable coordinator가 parent view controller를 탐색하거나 내부 hosting root를 별도 관리합니다.

주의:

- 셀마다 매번 새 hosting controller를 만들지 않습니다.
- reuse cycle에서 이전 SwiftUI view의 side effect가 남지 않게 합니다.
- 셀 크기 변경이 필요한 상태 변화는 layout invalidation 경로를 제공합니다.
- self-sizing cell은 compositional layout estimated size와 함께 테스트해야 합니다.

## Layout 전략

초기 제공 layout:

- `.plain`
- `.insetGrouped`
- `.grouped`
- `.sidebar`
- `.grid(columns:spacing:)`
- `.custom((Int, NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection)`

SwiftUI `listStyle`과 1:1 호환을 약속하지 않습니다. 대신 `listKitStyle` 또는 `collectionLayout` 명칭으로 `UICollectionViewCompositionalLayout` 기반 스타일을 제공합니다.

권장 API:

```swift
public enum LKListStyle {
    case plain
    case grouped
    case insetGrouped
    case sidebar
}

public enum LKSectionLayout {
    case list(appearance: UICollectionLayoutListConfiguration.Appearance)
    case grid(columns: Int, spacing: CGFloat)
    case custom((Int, NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection)
}
```

layout 우선순위:

1. row-level layout은 두지 않습니다.
2. section-level layout이 있으면 section layout을 사용합니다.
3. section-level layout이 없으면 list-level default layout을 사용합니다.

## Delegate 제공 범위

`ListKit`은 `UICollectionViewDelegate`의 주요 기능을 SwiftUI modifier 또는 delegate bridge로 제공합니다.

API는 두 단계로 나눕니다.

1. 자주 쓰는 기능은 typed modifier로 제공합니다.
2. 드물거나 UIKit 타입 의존성이 강한 기능은 `delegateProxy` 또는 `advancedDelegate`로 제공합니다.

### Selection

제공 대상:

- `shouldSelectItemAt`
- `didSelectItemAt`
- `shouldDeselectItemAt`
- `didDeselectItemAt`

권장 modifier:

```swift
.onShouldSelect { context in true }
.onSelect { context in }
.onShouldDeselect { context in true }
.onDeselect { context in }
.selection($selection)
.selectionMode(.none | .single | .multiple)
```

규칙:

- `selection(_:)` binding이 있으면 UIKit selection 상태와 SwiftUI state를 동기화합니다.
- `onShouldSelect`가 `false`를 반환하면 selection binding도 변경하지 않습니다.
- programmatic selection 변경도 collection view selection 상태에 반영합니다.
- `didSelect`와 `performPrimaryAction`은 별도 이벤트로 유지합니다.

### Highlight

제공 대상:

- `shouldHighlightItemAt`
- `didHighlightItemAt`
- `didUnhighlightItemAt`

권장 modifier:

```swift
.onShouldHighlight { context in true }
.onHighlight { context in }
.onUnhighlight { context in }
```

규칙:

- highlight는 selection과 독립적인 transient state입니다.
- SwiftUI row가 highlight state를 직접 알고 싶다면 environment value 제공을 검토합니다.
- 기본 눌림 효과는 UIKit cell selected/highlighted state와 충돌하지 않아야 합니다.

### Display Lifecycle

제공 대상:

- `willDisplay cell`
- `didEndDisplaying cell`
- `willDisplaySupplementaryView`
- `didEndDisplayingSupplementaryView`

권장 modifier:

```swift
.onWillDisplay { context in }
.onDidEndDisplaying { context in }
.onWillDisplayHeader { context in }
.onDidEndDisplayingHeader { context in }
.onWillDisplayFooter { context in }
.onDidEndDisplayingFooter { context in }
```

규칙:

- 이미지 로딩 시작/취소, 비디오 재생 준비/정리 같은 작업에 쓰는 것을 주 사용 사례로 문서화합니다.
- `didEndDisplaying`은 reuse와 화면 이탈 모두에서 호출될 수 있음을 문서화합니다.

### Context Menu

제공 대상:

- `contextMenuConfigurationForItemAt`
- `willPerformPreviewActionForMenuWith`
- `previewForHighlightingContextMenuWithConfiguration`
- `previewForDismissingContextMenuWithConfiguration`

SwiftUI 친화 API:

```swift
.contextMenu { context in
    Button("Archive") { archive(context.id) }
}
```

UIKit advanced API:

```swift
.uiContextMenuConfiguration { context, point in
    UIContextMenuConfiguration(...)
}
.onPreviewCommit { configuration, animator in }
.previewForHighlightingContextMenu { configuration in nil }
.previewForDismissingContextMenu { configuration in nil }
```

규칙:

- 단순 메뉴는 SwiftUI `View` 기반 context menu builder를 제공합니다.
- preview controller, targeted preview, commit animator는 UIKit 타입을 그대로 노출합니다.
- UIKit 타입이 public API에 들어가는 modifier는 `UIKit` 의존이 명확한 이름을 사용합니다.

### Primary Action

제공 대상:

- `canPerformPrimaryActionForItemAt`
- `performPrimaryActionForItemAt`

권장 modifier:

```swift
.onCanPerformPrimaryAction { context in true }
.onPrimaryAction { context in }
```

규칙:

- selection은 상태 변경이고 primary action은 실행 의도입니다.
- keyboard, pointer, remote, accessibility activation에서 primary action이 호출될 수 있음을 문서화합니다.

### Multiple Selection Interaction

제공 대상:

- `shouldBeginMultipleSelectionInteractionAt`
- `didBeginMultipleSelectionInteractionAt`
- `collectionViewDidEndMultipleSelectionInteraction`

권장 modifier:

```swift
.onShouldBeginMultipleSelectionInteraction { context in true }
.onBeginMultipleSelectionInteraction { context in }
.onEndMultipleSelectionInteraction { }
```

규칙:

- iPad 두 손가락 드래그 다중 선택을 주요 사용 사례로 둡니다.
- 이 기능은 `.selectionMode(.multiple)`과 함께 사용할 때만 기본 활성화합니다.
- 시작 callback에서 edit mode 진입을 유도할 수 있습니다.

### Focus

제공 대상:

- `canFocusItemAt`
- `shouldUpdateFocusIn`
- `didUpdateFocusIn`
- `indexPathForPreferredFocusedView`

권장 modifier:

```swift
.onCanFocus { context in true }
.onShouldUpdateFocus { context in true }
.onDidUpdateFocus { context, coordinator in }
.preferredFocusedItem(id: itemID)
```

규칙:

- tvOS, keyboard navigation, external input을 고려합니다.
- focus context는 UIKit 타입 의존성이 크므로 advanced API로 분류합니다.
- iOS만 목표로 하는 앱에서도 keyboard navigation 품질을 위해 유지합니다.

### Legacy Menu Actions

제공 대상:

- `shouldShowMenuForItemAt`
- `canPerformAction`
- `performAction`

권장 modifier:

```swift
.onShouldShowEditMenu { context in false }
.onCanPerformMenuAction { context, action, sender in false }
.onPerformMenuAction { context, action, sender in }
```

규칙:

- modern context menu와 다른 기능임을 문서화합니다.
- copy/paste/select 같은 `UIMenuController` 또는 edit menu 계열 기능에 사용합니다.

### Spring Loading

제공 대상:

- `shouldSpringLoadItemAt`

권장 modifier:

```swift
.onShouldSpringLoad { context, springContext in true }
```

규칙:

- drag 중 item 위에 잠시 머물렀을 때 열기/진입하는 동작을 제어합니다.
- UIKit 타입 의존성이 있으므로 advanced API로 분류합니다.

## Scroll Delegate 제공 범위

SwiftUI `List`와 차별화되는 중요한 영역입니다.

제공 대상:

- `scrollViewDidScroll`
- `scrollViewWillBeginDragging`
- `scrollViewWillEndDragging`
- `scrollViewDidEndDragging`
- `scrollViewWillBeginDecelerating`
- `scrollViewDidEndDecelerating`
- `scrollViewDidEndScrollingAnimation`
- `scrollViewShouldScrollToTop`
- `scrollViewDidScrollToTop`
- keyboard dismiss mode
- content inset adjustment
- scroll indicator visibility

권장 modifier:

```swift
.onScroll { context in }
.onWillBeginDragging { context in }
.onWillEndDragging { context in }
.onDidEndDragging { context in }
.onReachEnd(threshold: .points(300)) { }
.scrollIndicators(.hidden)
.keyboardDismissMode(.onDrag)
.contentInsets(...)
```

`onReachEnd`는 delegate callback이 아니라 편의 기능입니다. 내부적으로 content offset과 content size를 계산하되, 중복 호출 방지 정책을 명확히 둡니다.

## Refresh와 Search

`refreshable`:

- SwiftUI의 `.refreshable {}`와 유사한 modifier를 제공합니다.
- 내부적으로 `UIRefreshControl`을 사용합니다.
- async closure 완료 시 refresh control을 종료합니다.
- 외부 binding으로 refreshing 상태를 제어하는 API도 검토합니다.

권장 API:

```swift
.refreshable {
    await reload()
}
.refreshControlTint(.systemBlue)
```

`searchable`:

- SwiftUI `.searchable(text:)`와 가능한 한 유사한 호출부를 제공합니다.
- 실제 검색 UI는 SwiftUI navigation/search environment에 맡길지, UIKit `UISearchController`를 붙일지 별도 설계가 필요합니다.
- 1차 구현에서는 SwiftUI modifier pass-through 형태를 우선합니다.

권장 API:

```swift
.searchable(text: $query)
```

주의:

- `LKList` 자체가 `UIViewRepresentable`이므로 SwiftUI native `.searchable`과 조합될 수 있는지 먼저 확인합니다.
- UIKit `UISearchController`를 직접 제공하는 경우 navigation controller 의존성이 생기므로 별도 advanced API로 둡니다.

## Diffing 전략

### 공통 계약

모든 update engine은 다음 계약을 지켜야 합니다.

- apply는 main actor에서 실행합니다.
- update 중 새 update가 들어오면 마지막 요청을 보존하고 순차 처리합니다.
- duplicate id는 debug에서 빠르게 드러냅니다.
- diff 실패 시 fallback 정책을 명확히 합니다.
- selection 상태는 update 후 가능한 한 identity 기준으로 보존합니다.
- visible cell의 SwiftUI content는 최신 model을 반영해야 합니다.

### `UICollectionViewDiffableDataSource`

장점:

- Apple 공식 API
- 안정적인 snapshot apply
- collection view modern API와 궁합이 좋음
- section/item identifier 기반 mental model이 단순함

주의:

- item identifier의 hash/equality 설계가 중요합니다.
- content 변화만 있고 identifier가 같을 때 reload/reconfigure 전략을 별도로 세워야 합니다.
- `reconfigureItems` 사용 가능 여부를 iOS 버전에 맞춰 분기합니다.

권장 구현:

- `LKSectionIdentifier`
- `LKItemIdentifier`
- `NSDiffableDataSourceSnapshot<LKSectionIdentifier, LKItemIdentifier>`
- cell provider에서 coordinator snapshot을 조회해 content 구성
- content update는 `reconfigureItems` 또는 `reloadItems` 정책으로 처리

### `DifferenceKit`

장점:

- staged changeset을 통한 세밀한 batch update
- content equality와 identity 모델을 명확히 분리하기 쉬움
- 기존 UIKit adapter 스타일과 궁합이 좋음

주의:

- 외부 dependency입니다.
- staged update 중 data source 상태와 collection view update 순서가 어긋나면 crash가 납니다.
- reload/reconfigure 최적화는 직접 구현해야 합니다.

권장 구현:

- `LKSectionModel: DifferentiableSection`
- `LKItemModel: Differentiable`
- `differenceIdentifier`는 stable id
- `isContentEqual`은 equatable token 기반
- staged changeset 적용 전 내부 snapshot을 단계별로 갱신

### `reloadData`

용도:

- 초기 구현
- diff crash 회피
- 데이터가 작고 animation이 중요하지 않은 화면
- debug fallback

규칙:

- public option으로 제공합니다.
- selection/focus 복원은 best effort로 처리합니다.

## Public Modifier 설계 원칙

자주 쓰는 delegate는 modifier로 제공합니다.

예:

```swift
.onSelect { context in }
.onWillDisplay { context in }
.onScroll { context in }
```

반환값이 있는 delegate는 `onShould...` 또는 `can...` prefix를 사용합니다.

예:

```swift
.onShouldSelect { context in true }
.onCanFocus { context in true }
```

UIKit 타입을 직접 받는 고급 API는 이름에 UIKit 의존성이 드러나게 합니다.

예:

```swift
.uiContextMenuConfiguration { context, point in ... }
.uiPreviewForHighlightingContextMenu { configuration in ... }
```

modifier 병합 규칙:

- row-level handler가 있으면 row-level이 우선합니다.
- section-level handler가 있으면 그 다음으로 사용합니다.
- list-level handler가 마지막 fallback입니다.
- 여러 modifier를 같은 scope에 반복 적용하면 마지막 modifier가 이깁니다.

## 이벤트 라우팅 우선순위

delegate callback이 들어오면 다음 순서로 handler를 찾습니다.

1. item handler
2. section handler
3. list handler
4. default behavior

default behavior:

- `shouldSelect`: true
- `shouldDeselect`: true
- `shouldHighlight`: true
- `canPerformPrimaryAction`: true if primary action handler exists, otherwise false
- `shouldBeginMultipleSelectionInteraction`: true only when multiple selection mode
- `canFocus`: true
- menu 관련: false 또는 nil
- spring load: true

## Selection 상태 관리

지원 모드:

```swift
public enum LKSelectionMode {
    case none
    case single
    case multiple
}
```

binding:

```swift
.selection($selectedID)
.selection($selectedIDs)
```

규칙:

- `.none`이면 collection view selection을 비활성화합니다.
- `.single`이면 하나의 id만 유지합니다.
- `.multiple`이면 Set 기반 selection을 유지합니다.
- 데이터 update 후 사라진 item id는 selection에서 제거합니다.
- should delegate가 거부한 selection 변화는 binding에 반영하지 않습니다.
- binding 변화가 외부에서 들어오면 collection view의 selection도 동기화합니다.

## Supplementary View

지원 대상:

- header
- footer
- custom supplementary kind는 2차 목표

권장 API:

```swift
LKSection(id: section.id) {
    ...
} header: {
    HeaderView()
} footer: {
    FooterView()
}
```

내부:

- supplementary registration을 사용합니다.
- header/footer도 SwiftUI View로 hosting합니다.
- display lifecycle callback을 제공합니다.
- self-sizing supplementary view를 지원합니다.

## Prefetching

`UICollectionViewDataSourcePrefetching` 지원은 1차 고급 기능에 포함합니다.

제공 대상:

- `prefetchItemsAt`
- `cancelPrefetchingForItemsAt`

권장 modifier:

```swift
.onPrefetch { contexts in }
.onCancelPrefetch { contexts in }
```

규칙:

- context 배열은 최신 snapshot 기준으로 가능한 item만 포함합니다.
- prefetch callback에서 SwiftUI state를 직접 변경하는 예시는 피합니다.
- 이미지 로딩, 네트워크 warm-up, database fetch를 주요 사용 사례로 문서화합니다.

## Drag and Drop

2차 목표입니다.

제공 방향:

- SwiftUI friendly modifier 우선
- 복잡한 UIKit drag/drop session 제어는 advanced delegate로 제공

예상 API:

```swift
.onDragItem { context in UIDragItem(...) }
.onCanHandleDrop { session in true }
.onDropItems { coordinator in }
```

Drag/drop은 selection, reordering, diff update와 충돌하기 쉬우므로 별도 milestone에서 구현합니다.

## Reordering

2차 목표입니다.

지원 방향:

- interactive movement
- SwiftUI binding 기반 data reorder
- `canMoveItemAt`
- `moveItemAt sourceIndexPath to destinationIndexPath`

권장 API:

```swift
.onMove { source, destination in
    items.move(fromOffsets: source, toOffset: destination)
}
.onCanMove { context in true }
```

## Swipe Actions

SwiftUI `swipeActions`와 유사한 API를 목표로 하되, 내부는 collection view list cell accessories 또는 custom action view 중 하나를 선택해야 합니다.

1차 구현 필수는 아닙니다.

권장 방향:

- list appearance layout에서는 system swipe action 사용 가능성 검토
- grid/custom layout에서는 custom implementation 필요
- public API는 layout별 동작 차이를 숨기거나 명확히 문서화해야 합니다.

## Environment와 State 전달

셀 SwiftUI content는 다음 값을 environment로 받을 수 있어야 합니다.

- `isSelected`
- `isHighlighted`
- `isFocused`
- `indexPath`
- `sectionID`
- `itemID`

권장 environment keys:

```swift
\.listKitIsSelected
\.listKitIsHighlighted
\.listKitIsFocused
\.listKitIndexPath
\.listKitSectionID
\.listKitItemID
```

주의:

- environment update 때문에 과도한 cell reconfiguration이 발생하지 않도록 합니다.
- selection/highlight/focus는 UIKit cell state와 SwiftUI environment state를 동기화해야 합니다.

## Concurrency와 MainActor

규칙:

- public SwiftUI view API는 기본적으로 main actor 사용을 전제합니다.
- collection view 접근은 반드시 main actor에서 수행합니다.
- async refresh closure는 main actor를 점유하지 않게 호출합니다.
- update queue는 main actor에서 직렬화합니다.
- delegate callback에서 async 작업을 시작할 때는 item id를 캡처하고 indexPath에 의존하지 않습니다.

권장 내부 타입:

```swift
@MainActor
final class LKCoordinator: NSObject { ... }
```

`Sendable`:

- SwiftUI `View`와 UIKit 객체는 Sendable로 억지 포장하지 않습니다.
- event closure에 `@MainActor`를 붙이는 방향을 우선합니다.

## Error와 Diagnostics

debug build에서 잡아야 할 문제:

- duplicate section id
- duplicate item id
- section/item lookup 실패
- update engine과 snapshot 불일치
- background thread collection view 접근
- unsupported feature와 layout 조합

릴리즈 build 정책:

- fatalError보다 fallback/reload/log를 우선합니다.
- diff 적용 실패 시 `reloadData` fallback을 제공합니다.
- invalid callback은 조용히 무시하되 debug log를 남길 수 있습니다.

진단 API:

```swift
.listKitDiagnostics(.enabled)
.onListKitWarning { warning in }
```

1차 구현 필수는 아니지만 내부 warning enum은 초기에 설계해두는 것을 권장합니다.

## 테스트 전략

Core tests:

- section/item identity 안정성
- duplicate id detection
- model builder 결과
- modifier merge 우선순위
- event handler fallback 순서
- selection state reducer
- diffable snapshot 생성
- DifferenceKit changeset model 생성

UIKit integration tests:

- initial render
- update apply
- selection/deselection callback
- highlight callback
- willDisplay/didEndDisplaying callback
- supplementary display callback
- refresh control lifecycle
- prefetch callback
- selection restore after update

Snapshot/UI tests:

- plain list
- grouped list
- header/footer
- dynamic height row
- multiple selection
- empty state
- large data update

Performance tests:

- 1,000 rows initial render
- 10,000 identifiers snapshot creation
- repeated small updates
- self-sizing row scroll performance
- hosting reuse allocation count

## 구현 마일스톤

### Milestone 0: 패키지 정리

- iOS platform 지정
- 기본 target 구조 정리
- empty source 제거
- public namespace 결정 (`LK` prefix 또는 `ListKit` prefix)
- README skeleton 작성

완료 기준:

- `swift test` 통과
- 최소 public type 컴파일

### Milestone 1: 단일 섹션 기본 렌더링

- `LKList(data:id:rowContent:)`
- `UIViewRepresentable`
- `UICollectionView`
- 기본 compositional list layout
- `UIHostingConfiguration` cell
- `reloadData` update engine

완료 기준:

- SwiftUI 화면에서 row 표시
- 데이터 변경 시 reload
- dynamic height row 동작

### Milestone 2: 섹션 DSL

- `LKSection`
- `LKRow`
- result builder
- header/footer
- section layout descriptor

완료 기준:

- 여러 섹션 표시
- header/footer 표시
- section별 layout 적용

### Milestone 3: Delegate MVP

- should/did select
- should/did deselect
- should/did highlight
- will/did end display
- supplementary display lifecycle
- scroll callbacks

완료 기준:

- 사용자 예시의 delegate 대부분을 modifier로 처리
- event routing 우선순위 테스트

### Milestone 4: Diffable Data Source

- diffable data source adapter
- snapshot generation
- reload/reconfigure policy
- selection restore

완료 기준:

- insert/delete/move animation
- content update 반영
- duplicate id debug assertion

### Milestone 5: DifferenceKit Adapter

- dependency 분리
- `Differentiable` model adapter
- staged changeset apply
- fallback policy

완료 기준:

- DifferenceKit engine 선택 가능
- diffable engine과 동일한 public API 유지

### Milestone 6: Advanced Delegates

- context menu
- primary action
- multiple selection interaction
- focus
- legacy menu action
- spring loading
- prefetching

완료 기준:

- UIKit delegate 대응표의 모든 항목에 public hook 존재
- UIKit 타입 의존 API 문서화

### Milestone 7: SwiftUI 편의 기능

- refreshable
- searchable compatibility
- selection binding
- empty/background/overlay
- scroll position helper

완료 기준:

- SwiftUI `List`에서 기대하는 주요 편의 기능 제공
- UIKit 고급 기능과 함께 사용 가능

### Milestone 8: 문서와 예제

- README
- API reference style docs
- example app
- migration guide from SwiftUI List
- delegate cookbook
- performance guide

완료 기준:

- 새 사용자가 15분 안에 기본 리스트 작성 가능
- 고급 사용자가 원하는 delegate hook을 문서에서 찾을 수 있음

## Delegate 대응표

| UIKit delegate | ListKit API | 우선순위 |
| --- | --- | --- |
| `shouldSelectItemAt` | `.onShouldSelect` | 1차 |
| `didSelectItemAt` | `.onSelect` | 1차 |
| `shouldDeselectItemAt` | `.onShouldDeselect` | 1차 |
| `didDeselectItemAt` | `.onDeselect` | 1차 |
| `shouldHighlightItemAt` | `.onShouldHighlight` | 1차 |
| `didHighlightItemAt` | `.onHighlight` | 1차 |
| `didUnhighlightItemAt` | `.onUnhighlight` | 1차 |
| `willDisplay cell` | `.onWillDisplay` | 1차 |
| `didEndDisplaying cell` | `.onDidEndDisplaying` | 1차 |
| `willDisplaySupplementaryView` | `.onWillDisplayHeader/Footer` | 1차 |
| `didEndDisplayingSupplementaryView` | `.onDidEndDisplayingHeader/Footer` | 1차 |
| `contextMenuConfigurationForItemAt` | `.uiContextMenuConfiguration` | 2차 |
| `willPerformPreviewActionForMenuWith` | `.onPreviewCommit` | 2차 |
| `previewForHighlightingContextMenu` | `.uiPreviewForHighlightingContextMenu` | 2차 |
| `previewForDismissingContextMenu` | `.uiPreviewForDismissingContextMenu` | 2차 |
| `canPerformPrimaryActionForItemAt` | `.onCanPerformPrimaryAction` | 2차 |
| `performPrimaryActionForItemAt` | `.onPrimaryAction` | 2차 |
| `shouldBeginMultipleSelectionInteractionAt` | `.onShouldBeginMultipleSelectionInteraction` | 2차 |
| `didBeginMultipleSelectionInteractionAt` | `.onBeginMultipleSelectionInteraction` | 2차 |
| `collectionViewDidEndMultipleSelectionInteraction` | `.onEndMultipleSelectionInteraction` | 2차 |
| `canFocusItemAt` | `.onCanFocus` | 2차 |
| `shouldUpdateFocusIn` | `.onShouldUpdateFocus` | 2차 |
| `didUpdateFocusIn` | `.onDidUpdateFocus` | 2차 |
| `indexPathForPreferredFocusedView` | `.preferredFocusedItem` | 2차 |
| `shouldShowMenuForItemAt` | `.onShouldShowEditMenu` | 2차 |
| `canPerformAction` | `.onCanPerformMenuAction` | 2차 |
| `performAction` | `.onPerformMenuAction` | 2차 |
| `shouldSpringLoadItemAt` | `.onShouldSpringLoad` | 2차 |

## Naming 기준

외부 공개 이름은 SwiftUI 사용자에게 짧고 자연스러워야 합니다.

권장:

- `LKList`
- `LKSection`
- `LKRow`
- `LKListStyle`
- `LKUpdateEngine`
- `LKSelectionMode`

피해야 할 이름:

- `CollectionViewBackedSwiftUIListView`
- `AdvancedUICollectionViewRepresentableList`
- `DiffableDifferenceKitListAdapter`

내부 타입은 역할이 분명하면 길어도 됩니다.

예:

- `LKDiffableDataSourceAdapter`
- `LKDifferenceKitUpdateAdapter`
- `LKCollectionViewCoordinator`
- `LKSupplementaryRegistrationStore`

## 문서화 원칙

문서는 다음 질문에 답해야 합니다.

- SwiftUI `List` 대신 왜 쓰는가?
- 어떤 delegate를 어떤 modifier로 받을 수 있는가?
- diffable data source와 DifferenceKit 중 무엇을 골라야 하는가?
- identity/equality를 어떻게 설계해야 crash가 나지 않는가?
- selection과 primary action은 어떻게 다른가?
- dynamic height와 self-sizing은 어떻게 동작하는가?
- 성능 문제가 생기면 무엇을 확인해야 하는가?

README의 첫 예시는 너무 단순한 todo list가 아니라, `onSelect`, `onWillDisplay`, `refreshable`, `updateEngine`이 함께 보이는 예시가 좋습니다.

## 설계상 중요한 결정

1. `ListKit`은 SwiftUI `List`의 drop-in replacement가 아닙니다.
2. `ListKit`은 SwiftUI 스타일 API를 제공하는 collection view wrapper입니다.
3. 모든 delegate를 modifier로 억지 변환하지 않습니다.
4. 자주 쓰는 delegate는 typed modifier로, UIKit 의존이 큰 delegate는 advanced API로 둡니다.
5. diffing engine은 선택 가능해야 하지만 public list model은 하나여야 합니다.
6. cell identity와 content equality는 분리합니다.
7. selection은 identity 기반으로 보존합니다.
8. `IndexPath`는 callback 순간의 위치 정보이며 장기 식별자로 쓰지 않습니다.
9. SwiftUI content hosting 전략은 public API에 드러나지 않아야 합니다.
10. refresh/search/list style은 SwiftUI 느낌을 따르되 collection view 제약을 문서화합니다.

## 초기 구현에서 미루어도 되는 것

- drag/drop full support
- reordering full support
- swipe actions full support
- custom supplementary kind
- tvOS 전용 focus polish
- macCatalyst 전용 최적화
- custom refresh indicator
- scroll position preservation advanced API
- animated layout transition

미루더라도 내부 모델이 나중에 확장 가능해야 합니다.

## 초기 구현에서 미루면 안 되는 것

- stable identity 모델
- update engine abstraction
- delegate event routing 구조
- selection state 설계
- cell hosting reuse 정책
- section/item snapshot 조회 구조
- duplicate id diagnostics
- main actor collection view 접근 규칙

이 항목들은 나중에 바꾸면 public API와 내부 구조를 크게 흔듭니다.

## 리뷰 체크리스트

코드 리뷰 시 반드시 확인합니다.

- public API가 SwiftUI 사용처에서 읽기 쉬운가?
- UIKit delegate 의미가 왜곡되지 않았는가?
- handler 우선순위가 일관적인가?
- identity/equality가 분리되어 있는가?
- update 중 snapshot과 collection view 상태가 어긋나지 않는가?
- selection/focus/highlight 상태가 reuse 후에도 새지 않는가?
- cell hosting controller/configuration이 과도하게 생성되지 않는가?
- 모든 collection view 접근이 main actor에서 일어나는가?
- DifferenceKit dependency가 core API를 오염시키지 않는가?
- fallback과 diagnostics가 있는가?

## 성공 기준

`ListKit`이 1차로 성공했다고 판단하는 기준:

- SwiftUI view 안에서 10줄 내외로 기본 list를 만들 수 있습니다.
- 사용자는 `UICollectionViewDelegate`의 핵심 callback을 SwiftUI modifier로 받을 수 있습니다.
- 사용자는 Apple diffable data source와 DifferenceKit 중 하나를 선택할 수 있습니다.
- header/footer, dynamic height, refresh, selection이 함께 동작합니다.
- 대규모 데이터 update에서도 identity 기반으로 안정적으로 갱신됩니다.
- UIKit escape hatch가 있어 복잡한 앱에서도 막히지 않습니다.
- 문서만 보고 SwiftUI `List`에서 넘어올 때의 장단점을 이해할 수 있습니다.

## 전체 구현 체크리스트

이 체크리스트는 `ListKit`을 0부터 100까지 구현하기 위한 작업 추적표입니다. 개발자는 각 항목을 완료할 때 체크하고, 항목을 건너뛰는 경우 이유를 PR 또는 커밋 메시지에 남깁니다.

### 0. 패키지 기반 정리

- [x] `Package.swift`에 iOS platform 기준을 명시합니다.
- [x] Swift language mode와 minimum deployment target을 문서와 맞춥니다.
- [x] `Sources/ListKit/ListKit.swift`의 placeholder를 제거합니다.
- [x] `ListKit` public namespace와 `LK` prefix 사용 여부를 확정합니다.
- [x] UIKit/SwiftUI import가 가능한 platform 조건을 정리합니다.
- [x] 테스트 target이 iOS 의존 코드를 컴파일할 수 있는지 확인합니다.
- [x] 기본 `swift test` 또는 Xcode test 실행 경로를 문서화합니다.

완료 기준:

- [x] 빈 패키지가 아니라 최소 public type이 컴파일됩니다.
- [x] `swift test` 또는 대체 테스트 명령이 성공합니다.

### 1. Core Model

- [ ] `LKListModel`을 정의합니다.
- [ ] `LKSectionModel`을 정의합니다.
- [ ] `LKItemModel`을 정의합니다.
- [ ] `LKSupplementaryModel`을 정의합니다.
- [ ] section id를 `AnyHashable`로 안정적으로 저장합니다.
- [ ] item id를 `AnyHashable`로 안정적으로 저장합니다.
- [ ] item content equality용 `contentToken` 또는 `equatableToken`을 설계합니다.
- [ ] header/footer content equality용 token을 설계합니다.
- [ ] `IndexPath -> LKItemModel` lookup helper를 구현합니다.
- [ ] `section index -> LKSectionModel` lookup helper를 구현합니다.
- [ ] `section index + kind -> LKSupplementaryModel` lookup helper를 구현합니다.
- [ ] duplicate section id 검사 로직을 구현합니다.
- [ ] duplicate item id 검사 로직을 구현합니다.
- [ ] debug build assertion과 release fallback 정책을 분리합니다.

완료 기준:

- [ ] section/item/supplementary lookup 테스트가 통과합니다.
- [ ] duplicate id 테스트가 통과합니다.
- [ ] identity와 content equality가 별도 테스트로 검증됩니다.

### 2. Public SwiftUI API

- [ ] `LKList` 기본 타입을 정의합니다.
- [ ] `LKList(data:id:rowContent:)` initializer를 구현합니다.
- [ ] `LKList(@LKListBuilder content:)` initializer를 구현합니다.
- [ ] `LKSection` DSL 타입을 구현합니다.
- [ ] `LKRow` DSL 타입을 구현합니다.
- [ ] `@LKListBuilder`를 구현합니다.
- [ ] `@LKSectionBuilder` 또는 row builder를 구현합니다.
- [ ] 단일 섹션 data initializer가 `LKListModel`로 변환되게 합니다.
- [ ] 섹션 DSL이 `LKListModel`로 변환되게 합니다.
- [ ] row-level modifier 저장 구조를 만듭니다.
- [ ] section-level modifier 저장 구조를 만듭니다.
- [ ] list-level modifier 저장 구조를 만듭니다.

완료 기준:

- [ ] 단일 data list 예제가 컴파일됩니다.
- [ ] 여러 section/header/footer DSL 예제가 컴파일됩니다.
- [ ] builder 결과 모델 테스트가 통과합니다.

### 3. UIViewRepresentable Bridge

- [ ] `LKCollectionViewRepresentable`을 구현합니다.
- [ ] `makeUIView(context:)`에서 `UICollectionView`를 생성합니다.
- [ ] `updateUIView(_:context:)`에서 새 model을 adapter에 전달합니다.
- [ ] `Coordinator`를 생성하고 adapter를 소유하게 합니다.
- [ ] SwiftUI environment 변경이 adapter update에 반영되게 합니다.
- [ ] collection view background, indicator, inset 기본값을 정리합니다.
- [ ] representable이 SwiftUI layout 안에서 높이/폭을 안정적으로 받는지 확인합니다.

완료 기준:

- [ ] SwiftUI view에서 빈 collection view가 렌더링됩니다.
- [ ] data 변경 시 `updateUIView`가 adapter apply를 호출합니다.

### 4. Adapter 1차 구현

- [ ] `LKCollectionViewAdapter`를 `@MainActor final class`로 구현합니다.
- [ ] adapter가 `UICollectionViewDelegate`를 담당합니다.
- [ ] adapter가 `UICollectionViewDataSource`를 담당합니다.
- [ ] adapter가 현재 `LKListModel` snapshot을 보관합니다.
- [ ] adapter가 `registeredCellKeys` set을 보관합니다.
- [ ] adapter가 `registeredHeaderKeys` set을 보관합니다.
- [ ] adapter가 `registeredFooterKeys` set을 보관합니다.
- [ ] `LKCellRegistrationKey`를 구현합니다.
- [ ] `LKSupplementaryRegistrationKey`를 구현합니다.
- [ ] `registerReuseIdentifiersIfNeeded(from:)`를 구현합니다.
- [ ] `registerCellIfNeeded(_:)`를 구현합니다.
- [ ] `registerHeaderIfNeeded(_:)`를 구현합니다.
- [ ] `registerFooterIfNeeded(_:)`를 구현합니다.
- [ ] adapter는 cell/header/footer 인스턴스를 보관하지 않습니다.
- [ ] update 중 들어온 apply 요청을 `queuedUpdate`로 마지막 요청만 보존합니다.
- [ ] 최초 apply는 `reloadData`로 동작합니다.

완료 기준:

- [ ] cell/header/footer registration이 중복 호출되지 않는 테스트가 통과합니다.
- [ ] apply 중 queued update가 마지막 요청 기준으로 처리됩니다.
- [ ] adapter snapshot 조회 테스트가 통과합니다.

### 5. Hosting Cell과 Supplementary View

- [ ] `LKHostingCollectionViewCell`을 구현합니다.
- [ ] `LKHostingSupplementaryView`를 구현합니다.
- [ ] iOS 16 이상 `UIHostingConfiguration` 경로를 구현합니다.
- [ ] 필요 시 `UIHostingController` fallback 설계를 남깁니다.
- [ ] cell reuse 시 이전 content state가 새 row로 새지 않게 합니다.
- [ ] supplementary reuse 시 이전 header/footer state가 새 section으로 새지 않게 합니다.
- [ ] selected/highlighted/focused state를 SwiftUI environment로 전달하는 기반을 만듭니다.
- [ ] self-sizing이 필요한 경우 preferred fitting 경로를 구현합니다.
- [ ] size change callback이 adapter size storage로 전달되게 합니다.

완료 기준:

- [ ] SwiftUI row content가 cell에 표시됩니다.
- [ ] header/footer SwiftUI content가 supplementary view에 표시됩니다.
- [ ] reuse 후 다른 row content가 정확히 렌더링됩니다.

### 6. Layout

- [ ] 기본 `.plain` list layout을 구현합니다.
- [ ] `.grouped` layout을 구현합니다.
- [ ] `.insetGrouped` layout을 구현합니다.
- [ ] section-level layout override 구조를 구현합니다.
- [ ] grid layout descriptor를 구현합니다.
- [ ] custom `NSCollectionLayoutSection` provider API를 구현합니다.
- [ ] header/footer boundary supplementary item 생성 로직을 구현합니다.
- [ ] dynamic height row가 estimated size로 동작하게 합니다.
- [ ] layout adapter가 최신 section model을 조회하게 합니다.

완료 기준:

- [ ] plain/grouped/insetGrouped 예제가 표시됩니다.
- [ ] header/footer가 layout에 포함됩니다.
- [ ] dynamic height row가 잘리지 않습니다.

### 7. ReloadData Update Engine

- [ ] `LKUpdateEngine.reloadData`를 구현합니다.
- [ ] `LKUpdateCoordinator` 또는 adapter 내부 update 분기 구조를 만듭니다.
- [ ] reload 전 registration 선등록을 보장합니다.
- [ ] reload 후 current snapshot을 갱신합니다.
- [ ] reload 후 selection 복원을 best effort로 처리합니다.
- [ ] reload 후 focus 복원 hook을 남깁니다.

완료 기준:

- [ ] data append/remove/update가 reload로 화면에 반영됩니다.
- [ ] reload 후 visible cell이 최신 content를 표시합니다.

### 8. Diffable Data Source Engine

- [ ] `LKUpdateEngine.diffableDataSource`를 구현합니다.
- [ ] `LKSectionIdentifier`를 구현합니다.
- [ ] `LKItemIdentifier`를 구현합니다.
- [ ] `NSDiffableDataSourceSnapshot` 생성 로직을 구현합니다.
- [ ] diffable data source cell provider를 구현합니다.
- [ ] supplementary view provider를 구현합니다.
- [ ] content token 변경 시 reload/reconfigure 정책을 구현합니다.
- [ ] duplicate id가 diffable crash로 이어지기 전에 진단되게 합니다.
- [ ] apply completion에서 current snapshot을 갱신합니다.
- [ ] apply 중 새 요청 queueing과 diffable completion 순서를 맞춥니다.

완료 기준:

- [ ] insert/delete/move animation이 동작합니다.
- [ ] content update만 있는 row가 갱신됩니다.
- [ ] selection이 가능한 한 identity 기준으로 유지됩니다.

### 9. DifferenceKit Engine

- [ ] DifferenceKit dependency를 별도 target 또는 optional layer로 분리합니다.
- [ ] `LKSectionModel` adapter가 `DifferentiableSection`에 대응되게 합니다.
- [ ] `LKItemModel` adapter가 `Differentiable`에 대응되게 합니다.
- [ ] `differenceIdentifier`는 stable id를 사용합니다.
- [ ] `isContentEqual`은 content token을 사용합니다.
- [ ] staged changeset apply 순서를 구현합니다.
- [ ] staged update 중 내부 snapshot을 단계별로 갱신합니다.
- [ ] large changeset interrupt/fallback 정책을 구현합니다.
- [ ] failure 시 `reloadData` fallback을 제공합니다.

완료 기준:

- [ ] DifferenceKit engine 선택 시 insert/delete/move가 동작합니다.
- [ ] diffable engine과 동일한 public API를 사용합니다.
- [ ] DifferenceKit dependency가 core API를 오염시키지 않습니다.

### 10. Event Routing

- [ ] `LKListEvents`를 구현합니다.
- [ ] `LKSectionEvents`를 구현합니다.
- [ ] `LKRowEvents`를 구현합니다.
- [ ] `LKSupplementaryEvents`를 구현합니다.
- [ ] row-level handler 우선순위를 구현합니다.
- [ ] section-level handler fallback을 구현합니다.
- [ ] list-level handler fallback을 구현합니다.
- [ ] default behavior fallback을 구현합니다.
- [ ] `LKItemContext`를 구현합니다.
- [ ] `LKAnyItemContext`를 구현합니다.
- [ ] supplementary context를 구현합니다.
- [ ] scroll context를 구현합니다.

완료 기준:

- [ ] handler 우선순위 테스트가 통과합니다.
- [ ] 없는 handler는 default behavior로 처리됩니다.
- [ ] context가 최신 snapshot 기준 item/section id를 포함합니다.

### 11. UICollectionViewDelegate MVP

- [ ] `shouldSelectItemAt`를 `.onShouldSelect`로 연결합니다.
- [ ] `didSelectItemAt`를 `.onSelect`로 연결합니다.
- [ ] `shouldDeselectItemAt`를 `.onShouldDeselect`로 연결합니다.
- [ ] `didDeselectItemAt`를 `.onDeselect`로 연결합니다.
- [ ] `shouldHighlightItemAt`를 `.onShouldHighlight`로 연결합니다.
- [ ] `didHighlightItemAt`를 `.onHighlight`로 연결합니다.
- [ ] `didUnhighlightItemAt`를 `.onUnhighlight`로 연결합니다.
- [ ] `willDisplay cell`을 `.onWillDisplay`로 연결합니다.
- [ ] `didEndDisplaying cell`을 `.onDidEndDisplaying`로 연결합니다.
- [ ] `willDisplaySupplementaryView`를 header/footer display handler로 연결합니다.
- [ ] `didEndDisplayingSupplementaryView`를 header/footer end display handler로 연결합니다.

완료 기준:

- [ ] 각 delegate callback 단위 테스트 또는 integration 테스트가 통과합니다.
- [ ] callback context에 item id, section id, indexPath가 포함됩니다.

### 12. Selection

- [ ] `LKSelectionMode.none`을 구현합니다.
- [ ] `LKSelectionMode.single`을 구현합니다.
- [ ] `LKSelectionMode.multiple`을 구현합니다.
- [ ] single selection binding API를 구현합니다.
- [ ] multiple selection binding API를 구현합니다.
- [ ] external binding 변경이 collection view selection에 반영되게 합니다.
- [ ] user selection이 binding에 반영되게 합니다.
- [ ] `shouldSelect`가 false이면 binding이 변하지 않게 합니다.
- [ ] data update 후 사라진 id를 selection에서 제거합니다.
- [ ] selection environment 값을 cell content에 전달합니다.

완료 기준:

- [ ] single/multiple selection 테스트가 통과합니다.
- [ ] update 후 selection restore 테스트가 통과합니다.

### 13. Scroll Delegate와 편의 기능

- [ ] `scrollViewDidScroll`을 `.onScroll`로 연결합니다.
- [ ] `scrollViewWillBeginDragging`을 연결합니다.
- [ ] `scrollViewWillEndDragging`을 연결합니다.
- [ ] `scrollViewDidEndDragging`을 연결합니다.
- [ ] `scrollViewWillBeginDecelerating`을 연결합니다.
- [ ] `scrollViewDidEndDecelerating`을 연결합니다.
- [ ] `scrollViewShouldScrollToTop`을 연결합니다.
- [ ] `scrollViewDidScrollToTop`을 연결합니다.
- [ ] `.onReachEnd`를 구현합니다.
- [ ] reach end 중복 호출 방지 정책을 구현합니다.
- [ ] scroll indicator modifier를 구현합니다.
- [ ] keyboard dismiss mode modifier를 구현합니다.
- [ ] content inset modifier를 구현합니다.

완료 기준:

- [ ] scroll callback 테스트가 통과합니다.
- [ ] reach end가 threshold 기준으로 호출됩니다.

### 14. Refresh와 Search

- [ ] `.refreshable {}` API를 구현합니다.
- [ ] 내부 `UIRefreshControl` 연결을 구현합니다.
- [ ] async refresh closure 완료 시 refresh control을 종료합니다.
- [ ] refresh tint 설정 API를 구현합니다.
- [ ] 외부 refreshing binding 필요 여부를 결정합니다.
- [ ] SwiftUI `.searchable(text:)` pass-through 조합을 검증합니다.
- [ ] UIKit `UISearchController` 직접 제공 여부를 문서상 advanced API로 남깁니다.

완료 기준:

- [ ] pull to refresh가 동작합니다.
- [ ] async refresh 중복 실행 정책이 테스트됩니다.
- [ ] `.searchable` 사용 예제가 컴파일됩니다.

### 15. Prefetching

- [ ] adapter가 `UICollectionViewDataSourcePrefetching`을 담당합니다.
- [ ] `.onPrefetch` modifier를 구현합니다.
- [ ] `.onCancelPrefetch` modifier를 구현합니다.
- [ ] indexPaths를 최신 snapshot 기준 context 배열로 변환합니다.
- [ ] prefetch operation cache를 item id 또는 indexPath 정책에 맞춰 구현합니다.
- [ ] cancel 시 작업 정리 hook을 호출합니다.

완료 기준:

- [ ] prefetch/cancel callback 테스트가 통과합니다.
- [ ] 사라진 indexPath는 context에서 안전하게 제외됩니다.

### 16. Advanced UICollectionViewDelegate

- [ ] `contextMenuConfigurationForItemAt` advanced API를 구현합니다.
- [ ] SwiftUI friendly `.contextMenu` API와의 관계를 정리합니다.
- [ ] `willPerformPreviewActionForMenuWith`를 연결합니다.
- [ ] `previewForHighlightingContextMenuWithConfiguration`을 연결합니다.
- [ ] `previewForDismissingContextMenuWithConfiguration`을 연결합니다.
- [ ] `canPerformPrimaryActionForItemAt`를 연결합니다.
- [ ] `performPrimaryActionForItemAt`를 연결합니다.
- [ ] `shouldBeginMultipleSelectionInteractionAt`를 연결합니다.
- [ ] `didBeginMultipleSelectionInteractionAt`를 연결합니다.
- [ ] `collectionViewDidEndMultipleSelectionInteraction`을 연결합니다.
- [ ] `canFocusItemAt`를 연결합니다.
- [ ] `shouldUpdateFocusIn`을 연결합니다.
- [ ] `didUpdateFocusIn`을 연결합니다.
- [ ] `indexPathForPreferredFocusedView`를 연결합니다.
- [ ] `shouldShowMenuForItemAt`를 연결합니다.
- [ ] `canPerformAction`을 연결합니다.
- [ ] `performAction`을 연결합니다.
- [ ] `shouldSpringLoadItemAt`를 연결합니다.

완료 기준:

- [ ] delegate 대응표의 모든 항목에 public hook이 있습니다.
- [ ] UIKit 타입 의존 API는 advanced 이름을 사용합니다.

### 17. Environment Values

- [ ] `\.listKitIsSelected`를 구현합니다.
- [ ] `\.listKitIsHighlighted`를 구현합니다.
- [ ] `\.listKitIsFocused`를 구현합니다.
- [ ] `\.listKitIndexPath`를 구현합니다.
- [ ] `\.listKitSectionID`를 구현합니다.
- [ ] `\.listKitItemID`를 구현합니다.
- [ ] cell state 변화 시 environment가 갱신되게 합니다.
- [ ] environment 갱신이 불필요한 full reload를 유발하지 않게 합니다.

완료 기준:

- [ ] row content에서 environment 값을 읽는 예제가 동작합니다.
- [ ] selection/highlight/focus state가 reuse 후 새지 않습니다.

### 18. Diagnostics

- [ ] `LKListKitWarning` enum을 정의합니다.
- [ ] duplicate id warning을 구현합니다.
- [ ] invalid lookup warning을 구현합니다.
- [ ] unsupported feature/layout 조합 warning을 구현합니다.
- [ ] diff failure warning을 구현합니다.
- [ ] `.listKitDiagnostics(.enabled)` API를 구현합니다.
- [ ] `.onListKitWarning` API를 구현합니다.
- [ ] debug assertion과 runtime warning 경계를 문서화합니다.

완료 기준:

- [ ] diagnostics 테스트가 통과합니다.
- [ ] release build에서 치명적이지 않은 오류는 fallback 처리됩니다.

### 19. Tests

- [ ] model identity 테스트를 작성합니다.
- [ ] duplicate id 테스트를 작성합니다.
- [ ] builder 테스트를 작성합니다.
- [ ] modifier merge 테스트를 작성합니다.
- [ ] event routing 테스트를 작성합니다.
- [ ] adapter registration set 테스트를 작성합니다.
- [ ] reload update 테스트를 작성합니다.
- [ ] diffable update 테스트를 작성합니다.
- [ ] DifferenceKit update 테스트를 작성합니다.
- [ ] selection 테스트를 작성합니다.
- [ ] display lifecycle 테스트를 작성합니다.
- [ ] supplementary lifecycle 테스트를 작성합니다.
- [ ] refresh 테스트를 작성합니다.
- [ ] prefetch 테스트를 작성합니다.
- [ ] dynamic height 테스트를 작성합니다.
- [ ] large data performance 테스트를 작성합니다.

완료 기준:

- [ ] 핵심 테스트가 CI 또는 로컬 명령 한 번으로 실행됩니다.
- [ ] 실패 시 어느 레이어 문제인지 테스트 이름으로 추적 가능합니다.

### 20. Examples

- [ ] 단일 섹션 기본 list 예제를 작성합니다.
- [ ] 여러 섹션 header/footer 예제를 작성합니다.
- [ ] selection 예제를 작성합니다.
- [ ] refresh 예제를 작성합니다.
- [ ] search 조합 예제를 작성합니다.
- [ ] willDisplay/didEndDisplaying 이미지 로딩 예제를 작성합니다.
- [ ] context menu 예제를 작성합니다.
- [ ] grid layout 예제를 작성합니다.
- [ ] diffable engine 예제를 작성합니다.
- [ ] DifferenceKit engine 예제를 작성합니다.
- [ ] large data 예제를 작성합니다.

완료 기준:

- [ ] example app 또는 preview에서 주요 기능을 눈으로 확인할 수 있습니다.
- [ ] README의 첫 예제가 실제 코드와 일치합니다.

### 21. Documentation

- [ ] README 첫 예제를 작성합니다.
- [ ] SwiftUI `List`와의 차이를 문서화합니다.
- [ ] delegate 대응표를 README에 옮깁니다.
- [ ] identity/equality 가이드를 작성합니다.
- [ ] diffable vs DifferenceKit 선택 가이드를 작성합니다.
- [ ] selection vs primary action 차이를 문서화합니다.
- [ ] dynamic height/self-sizing 가이드를 작성합니다.
- [ ] refresh/search 사용법을 문서화합니다.
- [ ] performance troubleshooting을 작성합니다.
- [ ] migration guide from SwiftUI List를 작성합니다.

완료 기준:

- [ ] 새 사용자가 README만 보고 기본 list를 작성할 수 있습니다.
- [ ] 고급 사용자가 원하는 UIKit delegate hook을 문서에서 찾을 수 있습니다.

### 22. Release Readiness

- [ ] public API naming을 최종 점검합니다.
- [ ] `@available` annotation을 점검합니다.
- [ ] access control을 점검합니다.
- [ ] SPI로 숨길 타입과 public 타입을 분리합니다.
- [ ] binary/source compatibility에 민감한 generic API를 점검합니다.
- [ ] package products를 정리합니다.
- [ ] DifferenceKit optional product 구성을 점검합니다.
- [ ] license와 attribution을 확인합니다.
- [ ] changelog 초안을 작성합니다.
- [ ] semantic versioning 기준을 정합니다.

완료 기준:

- [ ] clean checkout에서 build/test가 통과합니다.
- [ ] README 예제가 그대로 컴파일됩니다.
- [ ] 1차 릴리즈 태그를 만들 수 있는 상태입니다.
