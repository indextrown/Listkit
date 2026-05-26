#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT_DIR/Examples/BenchmarkApp/BenchmarkApp.xcodeproj"
CSV_OUTPUT="$ROOT_DIR/Benchmarks/results/simulator-results.csv"
SVG_OUTPUT="$ROOT_DIR/Benchmarks/results/simulator-results.svg"
DESTINATION="${LISTKIT_BENCHMARK_DESTINATION:-platform=iOS Simulator,name=iPhone 15 Pro Max,OS=26.0}"
SIMULATOR_ID="${LISTKIT_BENCHMARK_SIMULATOR_ID:-}"
export LISTKIT_BENCHMARK_ITERATIONS="${LISTKIT_BENCHMARK_ITERATIONS:-3}"
export LISTKIT_BENCHMARK_IMPLEMENTATIONS="${LISTKIT_BENCHMARK_IMPLEMENTATIONS:-}"
export LISTKIT_BENCHMARK_SCROLL_UPS="${LISTKIT_BENCHMARK_SCROLL_UPS:-4}"
export LISTKIT_BENCHMARK_SCROLL_DOWNS="${LISTKIT_BENCHMARK_SCROLL_DOWNS:-2}"

if [[ -n "$SIMULATOR_ID" ]]; then
  DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
  xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_ID" -b
fi

mkdir -p "$(dirname "$CSV_OUTPUT")" "$(dirname "$SVG_OUTPUT")"

xcodebuild test \
  -project "$PROJECT" \
  -scheme BenchmarkApp \
  -destination-timeout 30 \
  -destination "$DESTINATION"

python3 "$ROOT_DIR/Benchmarks/scripts/render_chart.py" "$CSV_OUTPUT" "$SVG_OUTPUT"

echo "CSV: $CSV_OUTPUT"
echo "SVG: $SVG_OUTPUT"
