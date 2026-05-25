import XCTest

final class BenchmarkAppUITests: XCTestCase {
    private struct Scenario {
        let buttonTitle: String
        let csvTitle: String
        let itemCount: Int
    }

    private struct Result {
        let implementation: String
        let scenario: String
        let itemCount: Int
        let medianMilliseconds: Double
    }

    func testBenchmarksAndWriteCSV() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["run-scenario-button"].waitForExistence(timeout: 10))

        let implementations = ["ListKit", "SwiftUI List", "LazyVStack"]
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
            app.buttons[implementation].tap()

            for scenario in scenarios {
                app.buttons[scenario.buttonTitle].tap()

                var measurements = [Double]()
                for _ in 0..<iterations {
                    runID += 1
                    let start = CFAbsoluteTimeGetCurrent()
                    app.buttons["run-scenario-button"].tap()
                    waitForRun(app: app, runID: runID)
                    measurements.append((CFAbsoluteTimeGetCurrent() - start) * 1_000)
                }

                results.append(
                    Result(
                        implementation: implementation,
                        scenario: scenario.csvTitle,
                        itemCount: scenario.itemCount,
                        medianMilliseconds: median(measurements)
                    )
                )
            }
        }

        try writeCSV(results)
    }

    private func waitForRun(app: XCUIApplication, runID: Int) {
        let result = app.staticTexts["benchmark-result"]
        let predicate = NSPredicate(format: "label CONTAINS %@", "run \(runID)")
        expectation(for: predicate, evaluatedWith: result)
        waitForExpectations(timeout: 10)
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
        let configurationURL = repositoryRoot()
            .appendingPathComponent("Benchmarks")
            .appendingPathComponent("results")
            .appendingPathComponent(".benchmark-iterations")

        guard
            let value = try? String(contentsOf: configurationURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            let iterations = Int(value),
            iterations > 0
        else {
            return 3
        }

        return iterations
    }

    private func csvString(for results: [Result]) -> String {
        let header = "implementation,scenario,item_count,median_ms"
        let rows = results.map {
            [
                $0.implementation,
                $0.scenario,
                String($0.itemCount),
                String(format: "%.3f", $0.medianMilliseconds),
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
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
