"""Write the benchmark's measured rows to CSV and Markdown tables."""

import argparse
import csv
import html
import json
from pathlib import Path


def read(path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def flatten(record):
    row = {name: record[name] for name in ("id", "stock", "drying", "speed", "state", "layout", "mode", "wall_s", "sim_s")}
    row["sim_per_second"] = record["sim_s"] / record["wall_s"]
    row["steps_per_second"] = row["sim_per_second"] * 4
    row["fps"] = record["frames"]["n"] / record["wall_s"] if "frames" in record else None
    row["raster"] = record.get("raster")
    row["end_positive_conduction"] = record.get("end_positive_conduction")
    for group in ("frames", "step", "render_cpu", "render_gpu", "actions", "drag_preview"):
        for key, value in record.get(group, {}).items():
            row[f"{group}_{key}"] = value
    for key, values in record.get("readings", {}).items():
        row[f"{key}_median"] = values["p50"]
        row[f"{key}_max"] = values["max"]
    for key, (total, calls, worst) in record.get("profile", {}).items():
        row[f"{key}_calls"] = calls
        if key in ("candidate_pairs", "narrow_candidates", "accepted_links", "settle_population"):
            row[f"{key}_mean"] = total / calls if calls else 0
        else:
            row[f"{key}_total_ms"] = total / 1000
            row[f"{key}_mean_ms"] = total / calls / 1000 if calls else 0
            if key not in ("network.rejections", "network.visibility"):
                row[f"{key}_max_ms"] = worst / 1000
    return row


def print_table(out, rows, columns):
    def fmt(value):
        return "—" if value is None else (f"{value:.2f}" if isinstance(value, float) else str(value))

    print("| " + " | ".join(title for title, _ in columns) + " |", file=out)
    print("| " + " | ".join("---" for _ in columns) + " |", file=out)
    for row in rows:
        print("| " + " | ".join(fmt(row.get(key)) for _, key in columns) + " |", file=out)


def graph(path, rows):
    """Plot the reference window's tail latency as four drying-load series."""
    width, height = 1100, 540
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
           '<rect width="100%" height="100%" fill="#fbf8f2"/>']

    def label(x, y, text, size=15, anchor="start"):
        svg.append(f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="{size}" '
                   f'text-anchor="{anchor}" fill="#2a211b">{html.escape(text)}</text>')

    def line(x1, y1, x2, y2, color, stroke=1):
        svg.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{stroke}"/>')

    rows = [row for row in rows if row["run"] == "native"]
    label(37, 48, "Firetender · frame-time tail at 1920×1016", 25)
    label(37, 77, "P99 frame time (ms) by stored pieces and drying logs · stable coal bed", 16)
    colors = ["#58504a", "#52756a", "#8a6635", "#ab392a"]
    for i, (logs, color) in enumerate(zip((0, 3, 6, 9), colors)):
        x = 37 + 252 * i
        line(x, 110, x + 26, 110, color, 4)
        label(x + 35, 115, f"{logs} drying logs")
    max_y = max(100, 20 * int(max(float(r["frames_p99"]) for r in rows) / 20 + 1))
    for panel, speed in enumerate((1, 16, 64)):
        left = 58 + panel * 358
        base = 445
        panel_width = 283
        chart_height = 260
        label(left, 157, f"{speed}× requested", 18)
        for ms in range(0, max_y + 1, max_y // 5):
            y = base - ms * chart_height / max_y
            line(left, y, left + panel_width, y, "#e1d9cc")
            label(left - 9, y + 5, str(ms), 13, "end")
        for stock in (0, 20, 40, 60, 100):
            label(left + stock * panel_width / 100, base + 24, str(stock), 13, "middle")
        for logs, color in zip((0, 3, 6, 9), colors):
            series = sorted((r for r in rows if r["speed"] == speed and r["drying"] == logs), key=lambda r: r["stock"])
            points = [(left + r["stock"] * panel_width / 100, base - r["frames_p99"] * chart_height / max_y) for r in series]
            coord = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
            svg.append(f'<polyline points="{coord}" fill="none" stroke="{color}" stroke-width="3"/>')
            for x, y in points:
                svg.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4" fill="{color}"/>')
    label(550, 517, "Stored pieces", 15, "middle")
    svg.append("</svg>")
    path.write_text("\n".join(svg), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    directory = args.directory
    rows = []
    for path in sorted(directory.glob("*.jsonl")):
        batch = read(path)
        if not batch or not batch[0].get("meta"):
            continue
        for record in batch[1:]:
            if "stock" not in record:
                continue
            row = flatten(record)
            rows.append({"run": path.stem, **row})
    if not rows:
        parser.error("No benchmark rows found")
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with (directory / "results.csv").open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    with (directory / "matrix.md").open("w", encoding="utf-8") as out:
        for run, title in (("native", "1920×1016"), ("low", "1152×738")):
            print(f"## {title}\n", file=out)
            for speed in (1, 16, 64):
                print(f"### {speed}× requested\n", file=out)
                print_table(out, (r for r in rows if r["run"] == run and r["speed"] == speed), [
                    ("Stored", "stock"), ("Drying", "drying"), ("Mean ms", "frames_mean"),
                    ("Median ms", "frames_p50"), ("P95 ms", "frames_p95"), ("P99 ms", "frames_p99"),
                    ("Max ms", "frames_max"), ("FPS", "fps"), ("Sim s/s", "sim_per_second"),
                    ("Steps/s", "steps_per_second"),
                ])
                print(file=out)
    if sum(row["run"] == "native" for row in rows) == 60:
        graph(directory / "frame-time-p99.svg", rows)
