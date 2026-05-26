import XCTest

final class BenchmarkAppUITests: XCTestCase {
    private struct BenchmarkConfig {
        let iterations: Int?
        let implementations: [String]?
        let scrollUps: Int?
        let scrollDowns: Int?
    }

    private struct Scenario {
        let buttonTitle: String
        let csvTitle: String
        let itemCount: Int
    }

    private struct Result {
        let implementation: String
        let scenario: String
        let itemCount: Int
        let medianAppMilliseconds: Double
        let medianXCTestMilliseconds: Double
        let medianMemoryMegabytes: Double?
    }

    private struct ParsedResult {
        let runID: Int
        let implementation: String
        let scenario: String
        let itemCount: Int
        let appMilliseconds: Double
        let memoryMegabytes: Double?
    }

    private enum ScrollDirection {
        case up
        case down
    }

    func testBenchmarksAndWriteCSV() throws {
        let app = XCUIApplication()
        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["run-scenario-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(benchmarkMachineResult(app: app).waitForExistence(timeout: 10))

        let implementations = configuredValues(
            environmentName: "LISTKIT_BENCHMARK_IMPLEMENTATIONS",
            defaults: [
                "ListKit Diffable",
                "ListKit DifferenceKit",
                "ListKit Reload",
                "SwiftUI List",
                "LazyVStack",
                "UIKit Collection",
            ]
        )
        let scenarios = [
            Scenario(buttonTitle: "Load", csvTitle: "Initial load", itemCount: 1_000),
            Scenario(buttonTitle: "Append", csvTitle: "Append 250", itemCount: 1_250),
            Scenario(buttonTitle: "Shuffle", csvTitle: "Shuffle", itemCount: 1_000),
            Scenario(buttonTitle: "Replace", csvTitle: "Replace", itemCount: 1_000),
        ]
        let iterations = benchmarkIterations()
        var runID = 0
        var results = [Result]()

        for implementation in implementations {
            let implementationButtonID = "implementation-\(implementationID(for: implementation))"
            XCTAssertTrue(app.buttons[implementationButtonID].waitForExistence(timeout: 5))
            app.buttons[implementationButtonID].tap()

            for scenario in scenarios {
                let scenarioButtonID = "scenario-\(scenarioID(for: scenario.buttonTitle))"
                XCTAssertTrue(app.buttons[scenarioButtonID].waitForExistence(timeout: 5))
                app.buttons[scenarioButtonID].tap()

                var appMeasurements = [Double]()
                var xctestMeasurements = [Double]()
                var memoryMeasurements = [Double]()
                for _ in 0..<iterations {
                    runID += 1
                    let start = CFAbsoluteTimeGetCurrent()
                    app.buttons["run-scenario-button"].tap()
                    let parsedResult = waitForRun(app: app, runID: runID)
                    xctestMeasurements.append((CFAbsoluteTimeGetCurrent() - start) * 1_000)
                    appMeasurements.append(parsedResult.appMilliseconds)
                    if let memoryMegabytes = parsedResult.memoryMegabytes {
                        memoryMeasurements.append(memoryMegabytes)
                    }
                }

                results.append(
                    Result(
                        implementation: implementation,
                        scenario: scenario.csvTitle,
                        itemCount: appMeasurements.isEmpty ? scenario.itemCount : lastItemCount(app: app, fallback: scenario.itemCount),
                        medianAppMilliseconds: median(appMeasurements),
                        medianXCTestMilliseconds: median(xctestMeasurements),
                        medianMemoryMegabytes: memoryMeasurements.isEmpty ? nil : median(memoryMeasurements)
                    )
                )
            }

            var scrollMeasurements = [Double]()
            var scrollMemoryMeasurements = [Double]()
            for _ in 0..<iterations {
                runID += 1
                app.buttons["reset-scroll-memory-button"].tap()
                _ = waitForRun(app: app, runID: runID)

                let start = CFAbsoluteTimeGetCurrent()
                for _ in 0..<scrollUpCount() {
                    performBenchmarkScroll(app: app, direction: .up)
                }
                for _ in 0..<scrollDownCount() {
                    performBenchmarkScroll(app: app, direction: .down)
                }
                runID += 1
                app.buttons["sample-scroll-memory-button"].tap()
                _ = waitForRun(app: app, runID: runID)

                scrollMeasurements.append((CFAbsoluteTimeGetCurrent() - start) * 1_000)
                let parsedResult = parseResult(benchmarkMachineResultValue(app: app))
                if let memoryMegabytes = parsedResult?.memoryMegabytes {
                    scrollMemoryMeasurements.append(memoryMegabytes)
                }
            }

            results.append(
                Result(
                    implementation: implementation,
                    scenario: "Scroll memory peak",
                    itemCount: lastItemCount(app: app, fallback: 1_000),
                    medianAppMilliseconds: median(scrollMeasurements),
                    medianXCTestMilliseconds: median(scrollMeasurements),
                    medianMemoryMegabytes: scrollMemoryMeasurements.isEmpty ? nil : median(scrollMemoryMeasurements)
                )
            )
        }

        try writeCSV(results)
    }

    private func performBenchmarkScroll(app: XCUIApplication, direction: ScrollDirection) {
        let scrollTarget = benchmarkScrollTarget(app: app)
        switch direction {
        case .up:
            scrollTarget.swipeUp()
        case .down:
            scrollTarget.swipeDown()
        }
    }

    private func benchmarkScrollTarget(app: XCUIApplication) -> XCUIElement {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            return collectionView
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            return scrollView
        }

        return app
    }

    private func waitForRun(app: XCUIApplication, runID: Int) -> ParsedResult {
        let result = benchmarkMachineResult(app: app)
        let predicate = NSPredicate(format: "value CONTAINS %@", "run=\(runID)")
        expectation(for: predicate, evaluatedWith: result)
        waitForExpectations(timeout: 10)
        let value = benchmarkMachineResultValue(app: app)
        guard let parsedResult = parseResult(value) else {
            XCTFail("Could not parse benchmark result value: \(value)")
            return ParsedResult(
                runID: runID,
                implementation: "",
                scenario: "",
                itemCount: 0,
                appMilliseconds: 0,
                memoryMegabytes: nil
            )
        }
        return parsedResult
    }

    private func benchmarkMachineResult(app: XCUIApplication) -> XCUIElement {
        app.otherElements["benchmark-machine-result"]
    }

    private func benchmarkMachineResultValue(app: XCUIApplication) -> String {
        benchmarkMachineResult(app: app).value as? String ?? ""
    }

    private func writeCSV(_ results: [Result]) throws {
        let outputURL = repositoryRoot()
            .appendingPathComponent("Benchmarks")
            .appendingPathComponent("results")
            .appendingPathComponent("simulator-results.csv")
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try csvString(for: results).write(to: outputURL, atomically: true, encoding: .utf8)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func benchmarkIterations() -> Int {
        configuredPositiveInt(
            environmentName: "LISTKIT_BENCHMARK_ITERATIONS",
            configValue: benchmarkConfig().iterations,
            defaultValue: 3
        )
    }

    private func configuredValues(environmentName: String, defaults: [String]) -> [String] {
        guard
            let value = ProcessInfo.processInfo.environment[environmentName],
            value.isEmpty == false
        else {
            return benchmarkConfig().implementations?.isEmpty == false ? benchmarkConfig().implementations ?? defaults : defaults
        }
        return value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func scrollUpCount() -> Int {
        configuredPositiveInt(
            environmentName: "LISTKIT_BENCHMARK_SCROLL_UPS",
            configValue: benchmarkConfig().scrollUps,
            defaultValue: 4
        )
    }

    private func scrollDownCount() -> Int {
        configuredPositiveInt(
            environmentName: "LISTKIT_BENCHMARK_SCROLL_DOWNS",
            configValue: benchmarkConfig().scrollDowns,
            defaultValue: 2
        )
    }

    private func configuredPositiveInt(
        environmentName: String,
        configValue: Int?,
        defaultValue: Int
    ) -> Int {
        guard
            let value = ProcessInfo.processInfo.environment[environmentName],
            let count = Int(value),
            count >= 0
        else {
            return configValue.map { max($0, 0) } ?? defaultValue
        }
        return count
    }

    private func benchmarkConfig() -> BenchmarkConfig {
        let configURL = repositoryRoot()
            .appendingPathComponent("Benchmarks")
            .appendingPathComponent("results")
            .appendingPathComponent("benchmark-config.json")

        guard
            let data = try? Data(contentsOf: configURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return BenchmarkConfig(iterations: nil, implementations: nil, scrollUps: nil, scrollDowns: nil)
        }

        return BenchmarkConfig(
            iterations: object["iterations"] as? Int,
            implementations: object["implementations"] as? [String],
            scrollUps: object["scrollUps"] as? Int,
            scrollDowns: object["scrollDowns"] as? Int
        )
    }

    private func csvString(for results: [Result]) -> String {
        let header = "implementation,scenario,item_count,median_ms,median_app_ms,median_xctest_ms,median_memory_mb"
        let rows = results.map {
            [
                $0.implementation,
                $0.scenario,
                String($0.itemCount),
                String(format: "%.3f", $0.medianAppMilliseconds),
                String(format: "%.3f", $0.medianAppMilliseconds),
                String(format: "%.3f", $0.medianXCTestMilliseconds),
                $0.medianMemoryMegabytes.map { String(format: "%.3f", $0) } ?? "",
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private func parseResult(_ label: String) -> ParsedResult? {
        let fields = label.split(separator: " ").reduce(into: [String: String]()) { result, field in
            let parts = field.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            result[String(parts[0])] = String(parts[1])
        }

        guard
            label.contains("BENCH_RESULT"),
            let run = fields["run"].flatMap(Int.init),
            let implementation = fields["implementation"],
            let scenario = fields["scenario"],
            let items = fields["items"].flatMap(Int.init),
            let appMilliseconds = fields["app_ms"].flatMap(Double.init)
        else {
            return nil
        }

        return ParsedResult(
            runID: run,
            implementation: implementation,
            scenario: scenario,
            itemCount: items,
            appMilliseconds: appMilliseconds,
            memoryMegabytes: fields["memory_mb"].flatMap(Double.init)
        )
    }

    private func lastItemCount(app: XCUIApplication, fallback: Int) -> Int {
        parseResult(benchmarkMachineResultValue(app: app))?.itemCount ?? fallback
    }

    private func implementationID(for title: String) -> String {
        switch title {
        case "ListKit Diffable":
            "listKitDiffable"
        case "ListKit DifferenceKit":
            "listKitDifferenceKit"
        case "ListKit Reload":
            "listKitReloadData"
        case "SwiftUI List":
            "swiftUIList"
        case "LazyVStack":
            "lazyVStack"
        case "UIKit Collection":
            "uiCollectionView"
        default:
            title
        }
    }

    private func scenarioID(for title: String) -> String {
        switch title {
        case "Load":
            "initialLoad"
        case "Append":
            "append"
        case "Shuffle":
            "shuffle"
        case "Replace":
            "replace"
        default:
            title
        }
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }
}
