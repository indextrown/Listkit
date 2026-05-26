import SwiftUI
import UIKit
import Darwin
import ListKit

struct BenchmarkContentView: View {
    @State private var selectedImplementation = BenchmarkImplementation.listKitDiffable
    @State private var scenario = BenchmarkScenario.initialLoad
    @State private var itemCount = 1_000
    @State private var rows = BenchmarkRowModel.makeRows(count: 1_000)
    @State private var lastResult: BenchmarkRunResult?
    @State private var runID = 0
    @State private var scrollMemorySampler = BenchmarkMemorySampler()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BenchmarkControlPanel(
                    selectedImplementation: $selectedImplementation,
                    scenario: $scenario,
                    itemCount: $itemCount,
                    lastResult: lastResult,
                    runID: runID,
                    run: runScenario,
                    resetScrollMemory: resetScrollMemory,
                    sampleScrollMemory: sampleScrollMemory
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
        case .listKitDiffable:
            ListKitBenchmarkView(rows: rows, updateEngine: .diffableDataSource)
        case .listKitDifferenceKit:
            ListKitBenchmarkView(rows: rows, updateEngine: .differenceKit)
        case .listKitReloadData:
            ListKitBenchmarkView(rows: rows, updateEngine: .reloadData)
        case .swiftUIList:
            SwiftUIListBenchmarkView(rows: rows)
        case .lazyVStack:
            LazyVStackBenchmarkView(rows: rows)
        case .uiCollectionView:
            UIKitCollectionBenchmarkView(rows: rows)
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
                elapsedMilliseconds: elapsed,
                memoryMegabytes: BenchmarkMemory.currentFootprintMegabytes
            )
        }
    }

    private func sampleScrollMemory() {
        scrollMemorySampler.sample()
        runID += 1
        lastResult = BenchmarkRunResult(
            implementation: selectedImplementation,
            scenario: .scrollMemory,
            itemCount: rows.count,
            elapsedMilliseconds: 0,
            memoryMegabytes: scrollMemorySampler.peakMegabytes ?? BenchmarkMemory.currentFootprintMegabytes
        )
    }

    private func resetScrollMemory() {
        scrollMemorySampler = BenchmarkMemorySampler()
        sampleScrollMemory()
    }
}

private struct BenchmarkControlPanel: View {
    @Binding var selectedImplementation: BenchmarkImplementation
    @Binding var scenario: BenchmarkScenario
    @Binding var itemCount: Int

    let lastResult: BenchmarkRunResult?
    let runID: Int
    let run: () -> Void
    let resetScrollMemory: () -> Void
    let sampleScrollMemory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Implementation")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading, spacing: 8) {
                ForEach(BenchmarkImplementation.allCases) { implementation in
                    Button(implementation.title) {
                        selectedImplementation = implementation
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("implementation-\(implementation.rawValue)")
                }
            }

            Text("Scenario")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 8) {
                ForEach(BenchmarkScenario.allCases) { scenario in
                    Button(scenario.title) {
                        self.scenario = scenario
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("scenario-\(scenario.rawValue)")
                }
            }

            Stepper("Rows: \(itemCount)", value: $itemCount, in: 100...10_000, step: 100)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Run Scenario", action: run)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("run-scenario-button")

                    Button("Sample Scroll Memory", action: sampleScrollMemory)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("sample-scroll-memory-button")

                    Button("Reset Scroll Memory", action: resetScrollMemory)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("reset-scroll-memory-button")
                }

                if let lastResult {
                    Text("\(lastResult.summary), run \(runID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("benchmark-result")
                }

                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("benchmark-machine-result")
                    .accessibilityValue(lastResult?.machineSummary(runID: runID) ?? "BENCH_RESULT run=0 pending=true")
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

struct ListKitBenchmarkView: View {
    let rows: [BenchmarkRowModel]
    let updateEngine: LKUpdateEngine

    var body: some View {
        LKList(rows, id: \.id) { row in
            BenchmarkRow(row: row)
        }
        .listKitStyle(.plain)
        .updateEngine(updateEngine)
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

struct UIKitCollectionBenchmarkView: UIViewRepresentable {
    let rows: [BenchmarkRowModel]

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = context.coordinator
        collectionView.register(
            UIKitBenchmarkCollectionViewCell.self,
            forCellWithReuseIdentifier: UIKitBenchmarkCollectionViewCell.reuseIdentifier
        )
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.rows = rows
        collectionView.reloadData()
    }

    final class Coordinator: NSObject, UICollectionViewDataSource {
        var rows: [BenchmarkRowModel]

        init(rows: [BenchmarkRowModel]) {
            self.rows = rows
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            rows.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: UIKitBenchmarkCollectionViewCell.reuseIdentifier,
                for: indexPath
            )
            if let benchmarkCell = cell as? UIKitBenchmarkCollectionViewCell {
                benchmarkCell.configure(row: rows[indexPath.item])
            }
            return cell
        }
    }
}

final class UIKitBenchmarkCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "UIKitBenchmarkCollectionViewCell"

    private let swatchView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeLabel = UILabel()
    private let stackView = UIStackView()
    private let textStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }

    func configure(row: BenchmarkRowModel) {
        swatchView.backgroundColor = UIColor(row.color)
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        badgeLabel.text = row.badge
    }

    private func setUpViews() {
        swatchView.layer.cornerRadius = 6
        swatchView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatchView.widthAnchor.constraint(equalToConstant: 44),
            swatchView.heightAnchor.constraint(equalToConstant: 44),
        ])

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        badgeLabel.font = .preferredFont(forTextStyle: .caption1)
        badgeLabel.textColor = .secondaryLabel

        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(subtitleLabel)

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(swatchView)
        stackView.addArrangedSubview(textStackView)
        stackView.addArrangedSubview(badgeLabel)
        textStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
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
    case listKitDiffable
    case listKitDifferenceKit
    case listKitReloadData
    case swiftUIList
    case lazyVStack
    case uiCollectionView

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listKitDiffable:
            "ListKit Diffable"
        case .listKitDifferenceKit:
            "ListKit DifferenceKit"
        case .listKitReloadData:
            "ListKit Reload"
        case .swiftUIList:
            "SwiftUI List"
        case .lazyVStack:
            "LazyVStack"
        case .uiCollectionView:
            "UIKit Collection"
        }
    }
}

enum BenchmarkScenario: String, CaseIterable, Identifiable {
    case initialLoad
    case append
    case shuffle
    case replace
    case scrollMemory

    static let allCases: [BenchmarkScenario] = [
        .initialLoad,
        .append,
        .shuffle,
        .replace,
    ]

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
        case .scrollMemory:
            "Scroll Memory"
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
        case .scrollMemory:
            "Scroll memory peak"
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
        case .scrollMemory:
            break
        }
    }
}

struct BenchmarkRunResult {
    let implementation: BenchmarkImplementation
    let scenario: BenchmarkScenario
    let itemCount: Int
    let elapsedMilliseconds: Double
    let memoryMegabytes: Double?

    var summary: String {
        let memory = memoryMegabytes.map { ", \(String(format: "%.1f", $0)) MB" } ?? ""
        return "\(implementation.title) \(scenario.title): \(String(format: "%.2f", elapsedMilliseconds)) ms, \(itemCount) rows\(memory)"
    }

    func machineSummary(runID: Int) -> String {
        let memory = memoryMegabytes.map { String(format: "%.3f", $0) } ?? ""
        return [
            "BENCH_RESULT",
            "run=\(runID)",
            "implementation=\(implementation.rawValue)",
            "scenario=\(scenario.rawValue)",
            "items=\(itemCount)",
            "app_ms=\(String(format: "%.3f", elapsedMilliseconds))",
            "memory_mb=\(memory)",
        ].joined(separator: " ")
    }
}

struct BenchmarkMemorySampler {
    private(set) var peakMegabytes: Double?

    mutating func sample() {
        guard let current = BenchmarkMemory.currentFootprintMegabytes else {
            return
        }
        peakMegabytes = max(peakMegabytes ?? current, current)
    }
}

enum BenchmarkMemory {
    static var currentFootprintMegabytes: Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }
        return Double(info.phys_footprint) / 1_048_576
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
