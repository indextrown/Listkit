# ListKit Benchmarks

The benchmark app compares the same row model across:

- `ListKit` with `.updateEngine(.diffableDataSource)`
- SwiftUI `List`
- `ScrollView` + `LazyVStack`

The checked-in chart is generated from sample data. Treat it as a documentation example until you replace the CSV with measurements from your own device and build configuration.

## One Command

Run the UI test benchmark, write CSV, and render the SVG chart:

```sh
make benchmark
```

Default outputs:

```sh
Benchmarks/results/simulator-results.csv
Benchmarks/results/simulator-results.svg
```

The UI test target launches the simulator app, taps the benchmark controls, measures each `Run Scenario` interaction from the test process, writes the median timings to CSV, then the script renders the graph.

You can override the simulator and iteration count:

```sh
LISTKIT_BENCHMARK_DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=26.4" \
LISTKIT_BENCHMARK_ITERATIONS=5 \
make benchmark
```

## Run The App

```sh
xcodebuild \
  -project Examples/BenchmarkApp/BenchmarkApp.xcodeproj \
  -scheme BenchmarkApp \
  -destination 'generic/platform=iOS Simulator' \
  build
```

For useful numbers, prefer a physical device and a Release build. Simulator UI test numbers are still useful for local regression comparison, but they should be labeled as simulator measurements.

## Generate The Chart

Update or generate the CSV:

```sh
Benchmarks/results/sample-results.csv
```

Then render the SVG:

```sh
python3 Benchmarks/scripts/render_chart.py \
  Benchmarks/results/sample-results.csv \
  Benchmarks/results/listkit-benchmark-sample.svg
```

Commit the CSV and SVG together so the README chart always matches the source data.
