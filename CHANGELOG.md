# Changelog

All notable changes to ListKit will be documented in this file.

ListKit follows semantic versioning after the first tagged release.

## 0.1.0 - 2026-05-25

### Added

- SwiftUI-facing `LKList`, `LKSection`, and `LKRow` APIs backed by `UICollectionView`.
- List, section, and row event routing for selection, highlight, display lifecycle, scroll, prefetch, primary action, multiple selection interaction, focus, legacy menu actions, spring loading, and advanced UIKit context menu hooks.
- `UIHostingConfiguration` based cell and supplementary hosting.
- List and grid layout configuration through compositional layout.
- Update engine selection for reload data, diffable data source, and DifferenceKit.
- Selection binding synchronization and identity-based restoration.
- Refresh control integration and SwiftUI `.searchable` composition.
- Runtime diagnostics for invalid lookups, unsupported layout values, duplicate model IDs, and diff fallbacks.
- Previewable examples and README usage guides.

### Release Notes

- The current package ships as a single `ListKit` library product.
- DifferenceKit is a direct package dependency in this milestone; an optional product split remains a compatibility item to revisit before a stable 1.0 release.
- The repository is released under the MIT License.
