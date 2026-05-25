import SwiftUI
import ListKit

struct BenchmarkContentView: View {
    @State private var selectedImplementation = BenchmarkImplementation.listKit
    @State private var scenario = BenchmarkScenario.initialLoad
    @State private var itemCount = 1_000
    @State private var rows = BenchmarkRowModel.makeRows(count: 1_000)
    @State private var lastResult: BenchmarkRunResult?
    @State private var runID = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BenchmarkControlPanel(
                    selectedImplementation: $selectedImplementation,
                    scenario: $scenario,
                    itemCount: $itemCount,
                    lastResult: lastResult,
                    runID: runID,
                    run: runScenario
                )

                Divider()

                benchmarkView
            }
            .navigationTitle("ListKit Benchmark")
        }
    }

    @ViewBuilder
    private var benchmarkView: some View {
        switch selectedImplementation {
        case .listKit:
            ListKitBenchmarkView(rows: rows)
        case .swiftUIList:
            SwiftUIListBenchmarkView(rows: rows)
        case .lazyVStack:
            LazyVStackBenchmarkView(rows: rows)
        }
    }

    private func runScenario() {
        let start = CACurrentMediaTime()
        scenario.apply(to: &rows, itemCount: itemCount)

        DispatchQueue.main.async {
            let elapsed = (CACurrentMediaTime() - start) * 1_000
            runID += 1
            lastResult = BenchmarkRunResult(
                implementation: selectedImplementation,
                scenario: scenario,
                itemCount: rows.count,
                elapsedMilliseconds: elapsed
            )
        }
    }
}

private struct BenchmarkControlPanel: View {
    @Binding var selectedImplementation: BenchmarkImplementation
    @Binding var scenario: BenchmarkScenario
    @Binding var itemCount: Int

    let lastResult: BenchmarkRunResult?
    let runID: Int
    let run: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Implementation", selection: $selectedImplementation) {
                ForEach(BenchmarkImplementation.allCases) { implementation in
                    Text(implementation.title).tag(implementation)
                }
            }
            .pickerStyle(.segmented)

            Picker("Scenario", selection: $scenario) {
                ForEach(BenchmarkScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            .pickerStyle(.segmented)

            Stepper("Rows: \(itemCount)", value: $itemCount, in: 100...10_000, step: 100)

            HStack {
                Button("Run Scenario", action: run)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("run-scenario-button")

                if let lastResult {
                    Text("\(lastResult.summary), run \(runID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("benchmark-result")
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

struct ListKitBenchmarkView: View {
    let rows: [BenchmarkRowModel]

    var body: some View {
        LKList(rows, id: \.id) { row in
            BenchmarkRow(row: row)
        }
        .listKitStyle(.plain)
        .updateEngine(.diffableDataSource)
    }
}

struct SwiftUIListBenchmarkView: View {
    let rows: [BenchmarkRowModel]

    var body: some View {
        List(rows) { row in
            BenchmarkRow(row: row)
        }
        .listStyle(.plain)
    }
}

struct LazyVStackBenchmarkView: View {
    let rows: [BenchmarkRowModel]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    BenchmarkRow(row: row)
                    Divider()
                }
            }
        }
    }
}

private struct BenchmarkRow: View {
    let row: BenchmarkRowModel

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(row.color)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.headline)
                Text(row.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(row.badge)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

enum BenchmarkImplementation: String, CaseIterable, Identifiable {
    case listKit
    case swiftUIList
    case lazyVStack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listKit:
            "ListKit"
        case .swiftUIList:
            "SwiftUI List"
        case .lazyVStack:
            "LazyVStack"
        }
    }
}

enum BenchmarkScenario: String, CaseIterable, Identifiable {
    case initialLoad
    case append
    case shuffle
    case replace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .initialLoad:
            "Load"
        case .append:
            "Append"
        case .shuffle:
            "Shuffle"
        case .replace:
            "Replace"
        }
    }

    var csvTitle: String {
        switch self {
        case .initialLoad:
            "Initial load"
        case .append:
            "Append 250"
        case .shuffle:
            "Shuffle"
        case .replace:
            "Replace"
        }
    }

    func apply(to rows: inout [BenchmarkRowModel], itemCount: Int) {
        switch self {
        case .initialLoad:
            rows = BenchmarkRowModel.makeRows(count: itemCount)
        case .append:
            let startID = rows.count
            rows.append(contentsOf: BenchmarkRowModel.makeRows(count: 250, startID: startID))
        case .shuffle:
            rows.shuffle()
        case .replace:
            rows = BenchmarkRowModel.makeRows(count: rows.count)
        }
    }
}

struct BenchmarkRunResult {
    let implementation: BenchmarkImplementation
    let scenario: BenchmarkScenario
    let itemCount: Int
    let elapsedMilliseconds: Double

    var summary: String {
        "\(implementation.title) \(scenario.title): \(String(format: "%.2f", elapsedMilliseconds)) ms, \(itemCount) rows"
    }
}

struct BenchmarkRowModel: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let badge: String
    let colorIndex: Int

    var color: Color {
        BenchmarkPalette.colors[colorIndex % BenchmarkPalette.colors.count]
    }

    static func makeRows(count: Int, startID: Int = 0) -> [BenchmarkRowModel] {
        (0..<count).map { offset in
            let id = startID + offset
            return BenchmarkRowModel(
                id: id,
                title: "Benchmark row \(id)",
                subtitle: "Stable identity, hosted SwiftUI row content",
                badge: "#\(id)",
                colorIndex: id
            )
        }
    }
}

private enum BenchmarkPalette {
    static let colors: [Color] = [
        .blue.opacity(0.75),
        .green.opacity(0.75),
        .orange.opacity(0.75),
        .pink.opacity(0.75),
        .indigo.opacity(0.75),
    ]
}

#Preview {
    BenchmarkContentView()
}
