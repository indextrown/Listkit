#!/usr/bin/env python3
import csv
import html
import math
import sys
from collections import defaultdict
from pathlib import Path


COLORS = {
    "ListKit Diffable": "#2563eb",
    "ListKit DifferenceKit": "#7c3aed",
    "ListKit Reload": "#0891b2",
    "SwiftUI List": "#64748b",
    "LazyVStack": "#16a34a",
    "UIKit Collection": "#dc2626",
}


def load_rows(path):
    with open(path, newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def is_scroll_memory_scenario(scenario):
    return scenario.lower().startswith("scroll memory")


def tick_step(max_value):
    if max_value <= 0:
        return 1
    rough_step = max_value / 6
    magnitude = 10 ** math.floor(math.log10(rough_step))
    normalized = rough_step / magnitude
    if normalized <= 1:
        multiplier = 1
    elif normalized <= 2:
        multiplier = 2
    elif normalized <= 5:
        multiplier = 5
    else:
        multiplier = 10
    return multiplier * magnitude


def axis_ticks(max_value):
    step = tick_step(max_value)
    upper_bound = max(step, math.ceil(max_value / step) * step)
    ticks = []
    current = 0
    while current <= upper_bound + (step / 2):
        ticks.append(current)
        current += step
    return ticks, upper_bound


def render_axis(parts, left, plot_width, y, max_value):
    ticks, axis_max = axis_ticks(max_value)
    scale = plot_width / axis_max if axis_max else 1
    parts.append(f'<line x1="{left}" y1="{y}" x2="{left + plot_width}" y2="{y}" stroke="#cbd5e1"/>')
    for tick in ticks:
        x = left + tick * scale
        tick_label = f"{int(tick)}" if float(tick).is_integer() else f"{tick:.1f}"
        parts.append(f'<line x1="{x:.1f}" y1="{y - 4}" x2="{x:.1f}" y2="{y + 4}" stroke="#cbd5e1"/>')
        parts.append(f'<text x="{x:.1f}" y="{y + 20}" text-anchor="middle" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="11" fill="#64748b">{tick_label}</text>')
    return scale


def render_svg(rows):
    scenarios = []
    implementations = []
    grouped = defaultdict(dict)
    regular_max_value = 0.0
    scroll_max_value = 0.0

    for row in rows:
        scenario = row["scenario"]
        implementation = row["implementation"]
        value = float(row["median_ms"])
        if scenario not in scenarios:
            scenarios.append(scenario)
        if implementation not in implementations:
            implementations.append(implementation)
        grouped[scenario][implementation] = value
        if is_scroll_memory_scenario(scenario):
            scroll_max_value = max(scroll_max_value, value)
        else:
            regular_max_value = max(regular_max_value, value)

    width = 960
    row_height = max(96, 28 * len(implementations) + 32)
    top = 92
    left = 180
    bar_height = 16
    bar_gap = 7
    plot_width = 620
    section_gap = 24
    scroll_scenarios = [scenario for scenario in scenarios if is_scroll_memory_scenario(scenario)]
    height = top + len(scenarios) * row_height + (section_gap if scroll_scenarios else 0) + 120

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<text x="40" y="42" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="24" font-weight="700" fill="#0f172a">ListKit Benchmark</text>',
        '<text x="40" y="68" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="13" fill="#475569">median_ms uses app-side update time for update scenarios and XCTest wall time for scroll. Lower is better.</text>',
    ]

    for index, implementation in enumerate(implementations):
        x = left + (index % 3) * 210
        y = 82 + (index // 3) * 18
        color = COLORS.get(implementation, "#0f172a")
        parts.append(f'<rect x="{x}" y="{y}" width="12" height="12" rx="2" fill="{color}"/>')
        parts.append(f'<text x="{x + 18}" y="{y + 11}" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="12" fill="#334155">{html.escape(implementation)}</text>')

    regular_scale = render_axis(parts, left, plot_width, top + (len(scenarios) - len(scroll_scenarios)) * row_height + 8, regular_max_value)
    scroll_axis_y = height - 48
    scroll_scale = render_axis(parts, left, plot_width, scroll_axis_y, scroll_max_value) if scroll_scenarios else regular_scale

    for scenario_index, scenario in enumerate(scenarios):
        extra_gap = section_gap if scroll_scenarios and is_scroll_memory_scenario(scenario) else 0
        y = top + scenario_index * row_height + extra_gap + 36
        scale = scroll_scale if is_scroll_memory_scenario(scenario) else regular_scale
        parts.append(f'<text x="40" y="{y + 25}" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="14" font-weight="600" fill="#0f172a">{html.escape(scenario)}</text>')

        for implementation_index, implementation in enumerate(implementations):
            value = grouped[scenario].get(implementation)
            if value is None:
                continue
            bar_y = y + implementation_index * (bar_height + bar_gap)
            bar_width = max(2, value * scale)
            color = COLORS.get(implementation, "#0f172a")
            parts.append(f'<rect x="{left}" y="{bar_y}" width="{bar_width:.1f}" height="{bar_height}" rx="4" fill="{color}"/>')
            parts.append(f'<text x="{left + bar_width + 8:.1f}" y="{bar_y + 12}" font-family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="12" fill="#334155">{value:.1f} ms</text>')

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
