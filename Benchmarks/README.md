# ListKit Benchmarks

The benchmark app compares the same row model across:

- `ListKit` with `.updateEngine(.diffableDataSource)`
- `ListKit` with `.updateEngine(.differenceKit)`
- `ListKit` with `.updateEngine(.reloadData)`
- SwiftUI `List`
- `ScrollView` + `LazyVStack`
- UIKit `UICollectionView`

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

You can override the simulator, iteration count, implementations, and scroll memory pass from make arguments:

```sh
make benchmark \
  ITERATIONS=5 \
  DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro Max,OS=26.0" \
  IMPLEMENTATIONS="ListKit Diffable,ListKit DifferenceKit,SwiftUI List" \
  SCROLL_UPS=4 \
  SCROLL_DOWNS=2
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

If you already ran `make benchmark`, you can regenerate the chart directly from the benchmark output CSV:

```sh
python3 Benchmarks/scripts/render_chart.py \
  Benchmarks/results/simulator-results.csv \
  Benchmarks/results/simulator-results.svg
```

Commit the CSV and SVG together so the README chart always matches the source data.
