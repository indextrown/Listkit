#!/usr/bin/env python3
import csv
import html
import sys
from collections import defaultdict
from pathlib import Path


COLORS = {
    "ListKit": "#2563eb",
    "SwiftUI List": "#64748b",
    "LazyVStack": "#16a34a",
}


def load_rows(path):
    with open(path, newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def render_svg(rows):
    scenarios = []
    grouped = defaultdict(dict)
    max_value = 0.0

    for row in rows:
        scenario = row["scenario"]
        implementation = row["implementation"]
        value = float(row["median_ms"])
        if scenario not in scenarios:
            scenarios.append(scenario)
        grouped[scenario][implementation] = value
        max_value = max(max_value, value)

    implementations = ["ListKit", "SwiftUI List", "LazyVStack"]
    width = 960
    row_height = 96
    top = 92
    left = 180
    bar_height = 16
    bar_gap = 7
    plot_width = 620
    height = top + len(scenarios) * row_height + 84
    scale = plot_width / max_value if max_value else 1

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<text x="40" y="42" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="24" font-weight="700" fill="#0f172a">ListKit Benchmark Sample</text>',
        '<text x="40" y="68" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="13" fill="#475569">Median frame/update time in milliseconds. Lower is better. Replace sample-results.csv with your measured data.</text>',
    ]

    for index, implementation in enumerate(implementations):
        x = left + index * 150
        parts.append(f'<rect x="{x}" y="82" width="12" height="12" rx="2" fill="{COLORS[implementation]}"/>')
        parts.append(f'<text x="{x + 18}" y="93" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="12" fill="#334155">{html.escape(implementation)}</text>')

    for scenario_index, scenario in enumerate(scenarios):
        y = top + scenario_index * row_height + 36
        parts.append(f'<text x="40" y="{y + 25}" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="14" font-weight="600" fill="#0f172a">{html.escape(scenario)}</text>')

        for implementation_index, implementation in enumerate(implementations):
            value = grouped[scenario].get(implementation)
            if value is None:
                continue
            bar_y = y + implementation_index * (bar_height + bar_gap)
            bar_width = max(2, value * scale)
            color = COLORS[implementation]
            parts.append(f'<rect x="{left}" y="{bar_y}" width="{bar_width:.1f}" height="{bar_height}" rx="4" fill="{color}"/>')
            parts.append(f'<text x="{left + bar_width + 8:.1f}" y="{bar_y + 12}" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="12" fill="#334155">{value:.1f} ms</text>')

    parts.append(f'<line x1="{left}" y1="{height - 48}" x2="{left + plot_width}" y2="{height - 48}" stroke="#cbd5e1"/>')
    for tick in range(0, int(max_value) + 10, 10):
        x = left + tick * scale
        parts.append(f'<line x1="{x:.1f}" y1="{height - 52}" x2="{x:.1f}" y2="{height - 44}" stroke="#cbd5e1"/>')
        parts.append(f'<text x="{x:.1f}" y="{height - 28}" text-anchor="middle" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="11" fill="#64748b">{tick}</text>')

    parts.append("</svg>")
    return "\n".join(parts)


def main():
    if len(sys.argv) != 3:
        print("usage: render_chart.py input.csv output.svg", file=sys.stderr)
        return 2

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(render_svg(load_rows(input_path)), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
