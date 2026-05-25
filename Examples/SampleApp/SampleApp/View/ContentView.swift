//
//  ContentView.swift
//  SampleApp
//
//  Created by 김동현 on 5/25/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                ExampleNavigationRow(
                    title: "Basic List",
                    subtitle: "Plain list, selection callback, display lifecycle, refresh, diffable updates."
                ) {
                    BasicListExample()
                }

                ExampleNavigationRow(
                    title: "Sections",
                    subtitle: "Multiple sections with headers and footers."
                ) {
                    SectionedHeaderFooterExample()
                }

                ExampleNavigationRow(
                    title: "Selection",
                    subtitle: "Multiple selection with a should-select rule."
                ) {
                    SelectionExample()
                }

                ExampleNavigationRow(
                    title: "Refresh",
                    subtitle: "Async refresh control integration."
                ) {
                    RefreshExample()
                }

                ExampleNavigationRow(
                    title: "Search",
                    subtitle: "SwiftUI searchable composed with LKList."
                ) {
                    SearchExample()
                }

                ExampleNavigationRow(
                    title: "Display Lifecycle",
                    subtitle: "willDisplay and didEndDisplaying hooks."
                ) {
                    DisplayLifecycleExample()
                }

                ExampleNavigationRow(
                    title: "Prefetch",
                    subtitle: "Append the next page before reaching the end."
                ) {
                    PrefetchExample()
                }

                ExampleNavigationRow(
                    title: "Image Prefetch",
                    subtitle: "Prefetch and cancel image loading with collection view callbacks."
                ) {
                    ImagePrefetchExample()
                }

                ExampleNavigationRow(
                    title: "Context Menu",
                    subtitle: "SwiftUI row context menu."
                ) {
                    ContextMenuExample()
                }

                ExampleNavigationRow(
                    title: "Grid Layout",
                    subtitle: "Section-level grid layout."
                ) {
                    GridLayoutExample()
                }

                ExampleNavigationRow(
                    title: "Diffable Engine",
                    subtitle: "UICollectionViewDiffableDataSource update engine."
                ) {
                    DiffableEngineExample()
                }

                ExampleNavigationRow(
                    title: "DifferenceKit Engine",
                    subtitle: "DifferenceKit staged update engine."
                ) {
                    DifferenceKitEngineExample()
                }

                ExampleNavigationRow(
                    title: "Shuffle Diffable",
                    subtitle: "Shuffle rows with the diffable data source engine."
                ) {
                    ShuffleDiffableExample()
                }

                ExampleNavigationRow(
                    title: "Shuffle DifferenceKit",
                    subtitle: "Shuffle rows with the DifferenceKit update engine."
                ) {
                    ShuffleDifferenceKitExample()
                }

                ExampleNavigationRow(
                    title: "Large Data",
                    subtitle: "1,000 rows with diffable updates."
                ) {
                    LargeDataExample()
                }
            }
            .navigationTitle("ListKit Examples")
        }
    }
}

#Preview {
    ContentView()
}
