# ListKit

`ListKit` is a SwiftUI-facing list library backed by `UICollectionView`.

The project goal is to keep SwiftUI-style list declaration while exposing the collection view delegate surface that SwiftUI `List` does not provide directly.

## Current Status

Implementation is tracked in [AGENTS.md](./AGENTS.md). The first milestone establishes the package baseline, public `LK` namespace direction, and test command.

## Requirements

- Swift 6.3
- iOS 16.0+
- Swift Package Manager

## Test

```sh
swift test
```
