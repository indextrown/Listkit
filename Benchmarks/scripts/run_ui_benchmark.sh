#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT_DIR/Examples/BenchmarkApp/BenchmarkApp.xcodeproj"
CSV_OUTPUT="$ROOT_DIR/Benchmarks/results/simulator-results.csv"
SVG_OUTPUT="$ROOT_DIR/Benchmarks/results/simulator-results.svg"
DESTINATION="${LISTKIT_BENCHMARK_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.4}"
ITERATIONS="${LISTKIT_BENCHMARK_ITERATIONS:-3}"
ITERATIONS_FILE="$ROOT_DIR/Benchmarks/results/.benchmark-iterations"

mkdir -p "$(dirname "$CSV_OUTPUT")" "$(dirname "$SVG_OUTPUT")"
echo "$ITERATIONS" > "$ITERATIONS_FILE"
trap 'rm -f "$ITERATIONS_FILE"' EXIT

xcodebuild test \
  -project "$PROJECT" \
  -scheme BenchmarkApp \
  -destination "$DESTINATION"

python3 "$ROOT_DIR/Benchmarks/scripts/render_chart.py" "$CSV_OUTPUT" "$SVG_OUTPUT"

echo "CSV: $CSV_OUTPUT"
echo "SVG: $SVG_OUTPUT"
