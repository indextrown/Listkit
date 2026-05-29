# ListKit Wiki

이 문서는 구현 결정과 다음 작업 때 다시 참고할 맥락을 저장하는 내부 위키입니다.

## AnyView 없는 SwiftUI Hosting

### 배경

ListKit은 SwiftUI 문법으로 row, header, footer를 선언하지만 내부 렌더링은 `UICollectionView`에서 수행합니다. 이 구조에서는 서로 다른 SwiftUI view 타입을 하나의 list model 안에 담아야 합니다.

초기 구현은 이 문제를 단순하게 풀기 위해 각 row와 supplementary content를 `() -> AnyView` factory로 저장했습니다.

```swift
struct LKItemModel {
    let makeContent: @MainActor () -> AnyView
}

LKItemModel {
    AnyView(MessageRow(message: message))
}
```

이 방식은 구현이 쉽지만, 모든 사용자 view가 UIKit hosting으로 넘어가기 전에 먼저 `AnyView`로 지워집니다. `AnyView` 자체가 항상 병목이라는 뜻은 아니지만, ListKit의 기본 렌더링 경로에서 불필요한 wrapper를 강제하는 구조였습니다.

현재 구현은 사용자 view 자체를 `AnyView`로 감싸지 않고, "hosting 작업"만 타입 소거합니다.

### 핵심 아이디어

새 구조의 중심 타입은 `LKAnyViewContent`입니다.

파일:

- `Sources/ListKit/SwiftUI/LKAnyViewContent.swift`
- `Sources/ListKit/Core/LKItemModel.swift`
- `Sources/ListKit/Core/LKSupplementaryModel.swift`
- `Sources/ListKit/UIKit/LKHostingCollectionViewCell.swift`
- `Sources/ListKit/UIKit/LKHostingSupplementaryView.swift`

`LKAnyViewContent`는 public API가 아니라 내부 타입입니다. 역할은 heterogeneous SwiftUI content를 list model에 저장하되, 실제 렌더링 시점에는 concrete `Content: View`를 유지한 상태로 `UIHostingConfiguration`을 만들게 하는 것입니다.

```swift
struct LKAnyViewContent {
    private let box: any LKAnyViewContentBox

    init<Content: View>(@ViewBuilder _ makeContent: @escaping @MainActor () -> Content) {
        self.box = LKViewContentBox(makeContent: makeContent)
    }
}

private protocol LKAnyViewContentBox {
    @MainActor
    func makeCellContentConfiguration(
        state: LKCellState,
        indexPath: IndexPath?,
        sectionID: AnyHashable?,
        itemID: AnyHashable
    ) -> any UIContentConfiguration

    @MainActor
    func makeSupplementaryContentView(state: LKCellState) -> UIView
}

private struct LKViewContentBox<Content: View>: LKAnyViewContentBox {
    let makeContent: @MainActor () -> Content
}
```

타입 소거 대상은 SwiftUI view 값이 아니라 `makeCellContentConfiguration`, `makeSupplementaryContentView` 같은 UIKit hosting operation입니다.

### Row 저장 흐름

기존 `LKItemModel`은 `makeContent: (() -> AnyView)?`를 저장했습니다.

현재는 `content: LKAnyViewContent?`를 저장합니다.

```swift
public struct LKItemModel: Equatable {
    public let id: AnyHashable
    public let base: Any?
    public let reuseIdentifier: String
    public let hostingStrategy: LKHostingStrategy
    public let contentToken: AnyHashable?

    #if canImport(SwiftUI)
    var events: LKRowEvents
    let content: LKAnyViewContent?
    #endif
}
```

SwiftUI 전용 initializer는 `AnyView`를 받지 않고 generic `Content: View` builder를 받습니다.

```swift
init<Content: View>(
    id: some Hashable,
    base: Any? = nil,
    reuseIdentifier: String = "ListKit.LKHostingCollectionViewCell",
    hostingStrategy: LKHostingStrategy = .hostingConfiguration,
    contentToken: AnyHashable? = nil,
    events: LKRowEvents = LKRowEvents(),
    @ViewBuilder content: @escaping @MainActor () -> Content
) {
    self.id = AnyHashable(id)
    self.base = base
    self.reuseIdentifier = reuseIdentifier
    self.hostingStrategy = hostingStrategy
    self.contentToken = contentToken
    self.events = events
    self.content = LKAnyViewContent(content)
}
```

`LKList`와 `LKRow`는 더 이상 `AnyView(rowContent(element))`를 만들지 않습니다.

```swift
LKItemModel(
    id: element[keyPath: id],
    base: element
) {
    rowContent(element)
}
```

### Header/Footer 저장 흐름

`LKSupplementaryModel`도 같은 방식으로 바뀌었습니다.

기존에는 header/footer content를 `() -> AnyView`로 저장했습니다. 현재는 `LKAnyViewContent`를 저장합니다.

```swift
public struct LKSupplementaryModel: Equatable {
    public let id: AnyHashable
    public let kind: LKSupplementaryKind
    public let reuseIdentifier: String
    public let hostingStrategy: LKHostingStrategy
    public let contentToken: AnyHashable?

    #if canImport(SwiftUI)
    let content: LKAnyViewContent?
    #endif
}
```

`LKSection`의 header/footer builder도 `AnyView(header())`, `AnyView(footer())`를 만들지 않습니다.

```swift
LKSupplementaryModel(
    id: AnyHashable(id),
    kind: .header
) {
    header()
}
```

### Cell 렌더링 흐름

`LKHostingCollectionViewCell`은 `LKItemModel.content`를 꺼내서 content configuration 생성을 위임합니다.

```swift
guard let content = item.content else {
    contentConfiguration = nil
    return
}

contentConfiguration = content.makeCellContentConfiguration(
    state: cellState,
    indexPath: indexPath,
    sectionID: sectionID,
    itemID: item.id
)
```

실제 `UIHostingConfiguration`은 generic box 안에서 만들어집니다.

```swift
UIHostingConfiguration {
    makeContent()
        .environment(\.lkCellState, state)
        .environment(\.listKitIndexPath, indexPath)
        .environment(\.listKitSectionID, sectionID)
        .environment(\.listKitItemID, itemID)
}
```

이 지점에서 `makeContent()`의 반환 타입은 여전히 concrete `Content: View`입니다. ListKit이 `AnyView`를 추가로 씌우지 않습니다.

### Supplementary 렌더링 흐름

`LKHostingSupplementaryView`도 같은 구조입니다.

```swift
guard let content = supplementary.content else {
    hostedContentView = nil
    return
}

let contentView = content.makeSupplementaryContentView(state: state)
```

box 내부에서는 supplementary용 `UIHostingConfiguration`을 만들고 `makeContentView()`로 UIKit view를 얻습니다.

```swift
UIHostingConfiguration {
    makeContent()
        .environment(\.lkCellState, state)
}.makeContentView()
```

현재 supplementary에는 cell처럼 index path, section ID, item ID environment를 모두 주입하지 않습니다. 이후 header/footer context를 SwiftUI environment로 더 노출할 때 이 경로를 확장하면 됩니다.

### 왜 view가 아니라 hosting operation을 타입 소거했나

SwiftUI view 타입을 직접 하나의 배열에 저장하려면 결국 타입 소거가 필요합니다. 하지만 타입 소거의 위치를 어디에 두느냐가 중요합니다.

이전 구조:

1. 사용자 builder가 concrete `Content: View`를 만듭니다.
2. ListKit이 즉시 `AnyView`로 감쌉니다.
3. cell이 `AnyView`를 다시 `UIHostingConfiguration`에 넣습니다.

현재 구조:

1. 사용자 builder의 concrete `Content: View` factory를 generic box가 보관합니다.
2. list model은 box protocol existential만 저장합니다.
3. cell이 렌더링될 때 box가 concrete `Content`로 `UIHostingConfiguration`을 만듭니다.

즉, heterogeneity는 유지하되 SwiftUI 렌더링 트리에 `AnyView` wrapper를 추가하지 않는 방향입니다.

### 기대 효과와 한계

기대 효과:

- ListKit 기본 hosting 경로에서 불필요한 `AnyView` wrapper를 제거합니다.
- public API는 기존처럼 `@ViewBuilder`를 유지합니다.
- row/header/footer model은 heterogeneous content를 계속 저장할 수 있습니다.
- cell state, index path, section ID, item ID environment 주입 위치가 한 타입에 모입니다.

한계:

- 모든 화면에서 성능 향상을 보장하지 않습니다.
- 실제 비용은 row body 계산, SwiftUI diffing, `UIHostingConfiguration`, collection view update 방식에 더 크게 좌우될 수 있습니다.
- `LKAnyViewContent` 자체는 여전히 protocol existential을 사용합니다. 제거한 것은 SwiftUI view tree에 들어가는 `AnyView` wrapper입니다.
- iOS 16의 `UIHostingConfiguration` 경로를 기준으로 정리되어 있습니다. `UIHostingController` fallback을 추가하면 같은 abstraction 아래에 별도 operation을 넣어야 합니다.

### 관련 벤치마크에서 관찰한 점

`Benchmarks/results/simulator-results.csv` 기준으로, 업데이트 시나리오의 성능은 hosting wrapper 하나보다 update engine 전략의 영향이 큽니다.

특히:

- `Append 250`에서는 `ListKit DifferenceKit`이 `ListKit Diffable`보다 빠르게 측정되었습니다.
- `Shuffle`에서는 대규모 reorder를 그대로 animated diff로 처리하는 것보다 reload fallback이 유리할 수 있습니다.
- `Replace`는 모든 구현체가 거의 비슷해서 row hosting보다 측정 overhead나 단순 state 교체 비용이 더 커 보입니다.
- `Scroll memory peak`은 update benchmark가 아니라 UI test scroll pass 시간이므로 별도 해석해야 합니다.

따라서 AnyView 제거는 기본 렌더링 경로 정리로 보고, 성능 주장은 별도 device/release benchmark로만 해야 합니다.

### 다음에 이어서 볼 때 체크할 것

1. `LKAnyViewContent`가 public API로 노출되지 않는지 확인합니다.
2. `LKItemModel`과 `LKSupplementaryModel`의 `Equatable` 비교가 content closure를 비교하지 않는지 확인합니다.
3. `contentToken`은 여전히 content equality 판단용 metadata로만 사용합니다.
4. supplementary environment가 부족하면 `makeSupplementaryContentView` 인자에 section ID, kind, index path를 추가하는 방향을 검토합니다.
5. `UIHostingController` fallback을 만들 경우 `LKAnyViewContentBox`에 fallback operation을 추가하되 public initializer는 유지합니다.
6. 성능 문서에는 "AnyView 제거가 항상 빠르다"라고 쓰지 않습니다. "ListKit 기본 렌더링 경로에서 추가 AnyView wrapper를 만들지 않는다"라고 표현합니다.

### 관련 커밋

- `568d401 feat: AnyView 없는 콘텐츠 박스 추가`
- `8ce2527 feat: 아이템 모델 콘텐츠 저장 방식 개선`
- `fac3a98 feat: 보조 뷰 콘텐츠 저장 방식 개선`
- `f71cf28 feat: 리스트 초기화 콘텐츠 빌더 정리`
- `b838fc4 feat: 행 콘텐츠 빌더 경로 정리`
- `a157289 feat: 섹션 보조 뷰 빌더 경로 정리`
- `28c0e99 fix: 셀 호스팅 콘텐츠 구성 경로 수정`
- `51289b7 fix: 보조 뷰 호스팅 콘텐츠 구성 경로 수정`

## KarrotListKit 참고 기반 Adapter 성능 정리

### 참고한 구조

참고 저장소:

- https://github.com/daangn/KarrotListKit
- `/tmp/KarrotListKit/Sources/KarrotListKit/Adapter/CollectionViewAdapter.swift`
- `/tmp/KarrotListKit/Sources/KarrotListKit/Extension/UICollectionView+Difference.swift`
- `/tmp/KarrotListKit/Sources/KarrotListKit/Adapter/ComponentSizeStorage.swift`

KarrotListKit의 adapter는 collection view cell/header/footer 인스턴스를 저장하지 않고, 현재 list snapshot과 등록된 reuse identifier set, size storage, queued update만 보관합니다. ListKit도 같은 방향을 유지합니다.

핵심 대응:

- adapter는 `currentModel` snapshot을 소유합니다.
- cell/header/footer registration은 각각 `Set<LKCellRegistrationKey>`, `Set<LKSupplementaryRegistrationKey>`로 분리합니다.
- update 중 새 apply가 들어오면 마지막 update만 queue에 남깁니다.
- DifferenceKit staged update가 과도하게 커지면 reload fallback으로 전환합니다.
- size/cache류 상태는 view instance가 아니라 id 또는 index key 기반 저장소에 둡니다.

### 이번 복잡도 개선

기존 selection/focus 복원 경로는 선택된 item id마다 `indexPath(forItemID:in:)`가 전체 모델을 순회했습니다.

```swift
for selectedID in selectedItemIDs {
    indexPath(forItemID: selectedID, in: model) // sections/items 선형 탐색
}
```

이 구조는 선택 수를 `S`, 전체 item 수를 `N`이라고 할 때 `O(S * N)`입니다. 다중 선택이 많거나 apply가 자주 발생하는 화면에서는 update engine 자체보다 selection 동기화가 비용을 키울 수 있습니다.

현재는 `LKListModelIndex`를 추가해 model snapshot마다 한 번만 `itemID -> IndexPath` map과 live item id set을 만듭니다.

```swift
struct LKListModelIndex {
    let indexPathByItemID: [AnyHashable: IndexPath]
    let itemIDs: Set<AnyHashable>
}
```

adapter의 `currentModel`이 바뀌면 기존 `currentModelIndex` cache를 무효화합니다. selection restore, selection binding normalization, prefetch cache pruning, preferred focus lookup 중 하나가 실제로 필요할 때만 index를 만들고 같은 snapshot 안에서는 재사용합니다. selection/focus/prefetch가 없는 일반 update는 index 생성 비용을 내지 않습니다.

복잡도 변화:

- selection restore: `O(S * N)` -> `O(N + S)`
- selection binding normalization: `O(S * N)` -> `O(N + S)`
- selected id 적용: `O(S * N)` -> `O(N + S)`
- preferred focused item lookup: `O(N)` -> model 갱신 후 `O(1)`
- prefetch pruning: 매번 live id set 재생성 -> model index의 `itemIDs` 재사용

중복 item id가 전역으로 들어온 경우 기존 선형 탐색처럼 먼저 발견된 item을 index에 저장합니다. section 내부 duplicate id는 기존 validation warning/assertion 정책을 그대로 따릅니다.

### 함께 유지한 update 최적화

KarrotListKit의 `UICollectionView.reload(using:interrupt:setData:enablesReconfigureItems:)` 경로를 참고해 ListKit도 DifferenceKit staged changeset을 직접 적용하는 `lkReload` 경로를 둡니다.

적용한 정책:

- 첫 로드에서는 diff 계산 후 batch update를 시도하지 않고 reload로 초기화합니다.
- append-only update는 전체 registration scan 대신 삽입 item의 cell registration만 확인합니다.
- 대규모 reorder 또는 큰 staged changeset은 animated batch update 대신 reload fallback을 사용합니다.
- content token 변경은 가능한 경우 reload보다 `reconfigureItems`를 사용합니다.
- diffable data source도 첫 로드에서는 `applySnapshotUsingReloadData`를 사용하고, append-only update는 snapshot append 경로를 탑니다.

### 검증 상태

현재 확인:

- `swift test` 통과
- `make benchmark` 통과
- 결과 갱신:
  - `Benchmarks/results/simulator-results.csv`
  - `Benchmarks/results/simulator-results.svg`

주의:

- macOS SwiftPM 테스트에서는 UIKit 조건부 adapter 테스트가 실행되지 않을 수 있습니다.
- 현재 수치는 simulator Debug/UI test 기반입니다. 최종 성능 판단은 device Release benchmark를 별도로 봐야 합니다.

## Adapter 추가 성능 개선

### 1. Content token 변경 감지

`changedContentItemIdentifiers`는 이전에는 old model 전체를 `[LKItemIdentifier: LKItemModel]` dictionary로 만든 뒤 new model을 다시 순회했습니다.

현재는 `LKListContentTokenIndex`가 `LKModelItemIdentity(sectionID, itemID)` 기준으로 item 존재 여부와 content token만 저장합니다. 먼저 old/new model에 content token이 있는지 가볍게 확인하고, token이 있을 때만 token index를 만듭니다.

효과:

- old item model 전체 dictionary 저장을 피합니다.
- content token 비교에 필요한 값만 저장합니다.
- content token이 없는 일반 update는 token dictionary 할당을 건너뜁니다.

### 2. Append-only 판정

append-only 판정은 정확성을 위해 여전히 기존 prefix가 같은지 확인해야 합니다. hash/fingerprint만 믿으면 충돌 시 잘못된 batch update가 발생할 수 있으므로 사용하지 않습니다.

대신 현재 구현은 다음 비용을 줄입니다.

- 전체 inserted index path capacity를 미리 예약합니다.
- `prefix(...).elementsEqual(...)` 대신 명시적 index loop를 사용합니다.
- 첫 item과 old prefix의 마지막 item을 먼저 확인해 append-only가 아닌 update를 빠르게 탈락시킵니다.

append가 실제로 맞는 경우의 최악 시간복잡도는 정확성 때문에 `O(N)`입니다. append가 아닌 update에서는 boundary mismatch로 더 빨리 빠질 수 있습니다.

### 3. Registration summary

adapter는 cell/header/footer registration descriptor set을 `LKRegistrationSummary`로 만듭니다.

```swift
var cellDescriptors: Set<LKCellRegistrationDescriptor>
var headerDescriptors: Set<LKSupplementaryRegistrationDescriptor>
var footerDescriptors: Set<LKSupplementaryRegistrationDescriptor>
```

registration 정책은 summary 생성과 UIKit register 적용 단계로 분리됐습니다. append-only update는 기존처럼 inserted item만 등록하고, 일반 update는 summary를 통해 registration key 생성을 한 곳에서 처리합니다.

### 4. Size storage key

이전 size storage는 cell과 supplementary size를 `IndexPath` 중심으로 저장했습니다.

현재는 identity와 content token을 포함한 key를 사용합니다.

```swift
struct LKItemSizeKey {
    let sectionID: AnyHashable
    let itemID: AnyHashable
    let contentToken: AnyHashable?
}

struct LKSupplementarySizeKey {
    let kind: String
    let sectionID: AnyHashable
    let supplementaryID: AnyHashable
    let contentToken: AnyHashable?
}
```

reorder 이후에도 같은 item의 size cache 의미가 유지되고, content token이 바뀌면 이전 size를 다른 content의 size로 오해하지 않습니다.

### 5. Benchmark configuration

`make benchmark`는 기존 Debug simulator 측정과 호환되도록 기본값을 유지합니다. 추가로 `CONFIGURATION` 인자를 받아 Release 측정을 실행할 수 있습니다.

```sh
make benchmark CONFIGURATION=Release
```

`Benchmarks/results/benchmark-config.json`에도 configuration을 기록합니다. simulator Debug/UI test 수치는 회귀 비교용이고, 최종 성능 판단은 device Release 측정으로 보는 것을 권장합니다.

## Custom layout 이슈 정리

### 1. `.pinnedHeader()`가 custom section header에 반영되지 않던 문제

문제:

`.sectionLayout(.custom(...))` 경로는 provider가 반환한 `NSCollectionLayoutSection`을 그대로 반환했습니다. `.pinnedHeader()`는 `LKSectionModel.pinsHeader`만 바꾸고, custom provider가 만든 header boundary supplementary item의 `pinToVisibleBounds`에는 반영되지 않았습니다.

해결방법:

`LKCollectionLayoutProvider.makeSection(_:sectionIndex:model:environment:)`의 `.custom` 분기에서 provider가 만든 section의 `boundarySupplementaryItems`를 순회합니다. `elementKind == UICollectionView.elementKindSectionHeader`인 item에만 `pinToVisibleBounds = model.pinsHeader`를 적용합니다.

정책:

- header boundary item에만 pin 값을 반영합니다.
- footer boundary item은 변경하지 않습니다.
- custom provider가 만든 header size, alignment, contentInsets는 유지합니다.
- custom provider가 header를 만들지 않은 경우 ListKit이 기본 header를 자동 추가하지 않습니다.

### 2. custom layout helper 사용 시 Swift concurrency warning이 나던 문제

문제:

앱에서 아래처럼 custom layout provider를 helper 함수로 만들어 전달할 때 Swift 6 strict concurrency 경고가 날 수 있었습니다.

```swift
.sectionLayout(.custom(Self.horizontalSectionLayout(width: 194, height: 271, spacing: 15)))
```

경고:

```text
Converting non-Sendable function value to '@MainActor @Sendable (Int, any NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection' may introduce data races
```

원인은 `LKSectionLayout.custom` associated value가 `@MainActor` closure를 직접 요구해서, 앱의 plain function value가 더 강한 actor/sendability 요구를 가진 함수 타입으로 변환되기 때문입니다.

해결방법:

custom provider 저장 타입을 별도 public typealias로 분리하고, associated value에서는 plain provider를 받습니다.

```swift
public typealias LKCustomSectionLayoutProvider = (
    Int,
    NSCollectionLayoutEnvironment
) -> NSCollectionLayoutSection

public enum LKSectionLayout {
    case custom(LKCustomSectionLayoutProvider)
}
```

ListKit의 layout 생성 경로인 `LKCollectionLayoutProvider`는 `@MainActor`에 남아 있으므로 UIKit compositional layout section 생성은 기존처럼 main actor에서 수행됩니다. public API에서는 앱 helper 함수가 불필요하게 `@MainActor @Sendable` 함수 타입으로 변환되지 않게 합니다.

## Scroll API

문제:

앱에서 리스트를 최상단이나 특정 위치로 이동시키려면 `UICollectionView`를 직접 찾아야 했습니다. SwiftUI 화면이 `UIViewRepresentable`로 view tree를 탐색하고 `setContentOffset`을 호출하는 방식은 ListKit 내부 구현을 앱 코드가 알아야 하므로 유지보수하기 어렵습니다.

해결방법:

`LKListProxy`를 통해 SwiftUI에서 스크롤을 제어합니다.

```swift
@State private var listProxy = LKListProxy()

LKList {
    // sections
}
.listProxy(listProxy)

Button("Top") {
    listProxy.scrollToTop(animated: true)
}
```

제공 API:

- `scrollToTop(animated:)`: `adjustedContentInset.top`을 고려해 실제 최상단으로 이동합니다.
- `scrollToOffset(_:animated:)`: 임의의 content offset으로 이동합니다.
- `scrollToItem(id:sectionID:position:animated:)`: item id 기반으로 특정 row 위치로 이동합니다.
- `scrollToSection(id:position:animated:)`: section id 기반으로 해당 section의 첫 item 또는 header 위치로 이동합니다.

정책:

- proxy 호출은 `@MainActor`에서 동작합니다.
- 기존 `LKList` 사용 코드는 `.listProxy(...)`를 붙이지 않아도 그대로 동작합니다.
- 향후 row/section id 기반 확장을 위해 top 이동만 별도 closure로 두지 않고 proxy 타입으로 분리했습니다.

## Pinned header 배경 처리

문제:

`pinnedHeader`가 셀 위에 고정될 때 SwiftUI header content 주변의 좌우 또는 상단 여백이 투명하면 아래 셀 이미지와 내용이 비쳐 보일 수 있습니다. header content에 `.background(...)`를 붙여도 `UICollectionView` supplementary view 전체 영역과 hosting root view가 투명하면 여백 영역은 계속 비칠 수 있습니다.

해결방법:

pinned header에 사용할 배경색을 section modifier로 지정합니다.

```swift
LKSection(id: "best") {
    // rows
} header: {
    BestHeader()
}
.pinnedHeader(background: Color.subWhite)
```

또는 pinning과 별도로 배경만 설정할 수 있습니다.

```swift
.pinnedHeader()
.headerBackground(Color.subWhite)
```

정책:

- 배경색은 supplementary reusable view와 hosted SwiftUI root view 양쪽에 적용합니다.
- supplementary view frame이 section contentInsets 안쪽에 잡히는 custom layout에서도 full-bleed background layer를 collection view 폭까지 확장합니다.
- header content는 기존 supplementary view frame 안에 유지하므로 텍스트와 버튼 정렬은 section contentInsets 기준에서 바뀌지 않습니다.
- custom compositional layout provider가 직접 만든 header boundary item에도 동작합니다.
- header layout size, alignment, contentInsets는 custom provider가 만든 값을 유지합니다.
- 기본값은 `nil`이므로 기존 header의 투명 배경 동작은 명시적으로 배경을 지정하지 않는 한 바뀌지 않습니다.
