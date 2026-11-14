"""Compare matched Firetender performance JSONL captures and replay traces."""

import argparse
import csv
import json
from pathlib import Path
from statistics import median


def read_cases(path):
    with path.open(encoding="utf-8") as capture:
        rows = [json.loads(line) for line in capture]
    return {row["id"]: row for row in rows if "id" in row}


def measurements(row):
    fields = {"sim_per_second": row["sim_s"] / row["wall_s"]}
    if "frames" in row:
        fields["fps"] = row["frames"]["n"] / row["wall_s"]
    for group in ("frames", "step", "actions"):
        for metric in ("mean", "p95", "p99", "max"):
            value = row.get(group, {}).get(metric)
            if value is not None:
                fields[f"{group}_{metric}_ms"] = value
    for key in ("static_mem", "objects", "nodes", "links"):
        if key in row["readings"]:
            fields[f"{key}_median"] = row["readings"][key]["p50"]
    for key in ("first_promotion_frame_ms", "first_promotion_step_ms", "promotion_window_max_ms", "peak_active"):
        if key in row:
            fields[key] = row[key]
    return fields


def compare(root, mode, expected):
    before = read_cases(root / f"before-{mode}.jsonl")
    after = read_cases(root / f"after-{mode}.jsonl")
    if before.keys() != after.keys() or len(before) != expected:
        raise ValueError(f"{mode}: expected {expected} identical case IDs, got {len(before)} and {len(after)}")
    rows = []
    for case, baseline in before.items():
        row = {key: baseline[key] for key in ("id", "stock", "drying", "speed", "state", "layout", "mode")}
        old = measurements(baseline)
        new = measurements(after[case])
        for key in sorted(old.keys() | new.keys()):
            row[f"before_{key}"] = old.get(key)
            row[f"after_{key}"] = new.get(key)
        rows.append(row)
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with (root / f"comparison-{mode}.csv").open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"{mode}: {len(rows)} matched cases")
    for speed in (1, 16, 64):
        cases = [row for row in rows if row["speed"] == speed]
        if not cases:
            continue
        keys = ("fps", "frames_p99_ms", "step_mean_ms", "sim_per_second")
        values = [
            f"{key} {median(row['before_' + key] for row in cases):.2f} -> "
            f"{median(row['after_' + key] for row in cases):.2f}"
            for key in keys if "before_" + key in cases[0]
        ]
        print(f"  {speed}x  " + "  ".join(values))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_dir", type=Path)
    parser.add_argument("--thermal-scalability", action="store_true")
    args = parser.parse_args()
    modes = (
        ("thermal_scalability", 32), ("headless_thermal_scalability", 32),
        ("promotion", 1), ("headless_promotion", 1),
    ) if args.thermal_scalability else (
        ("architecture", 120), ("headless_architecture", 120),
        ("architecture_actions", 9), ("headless_architecture_actions", 9),
    )
    for mode, expected in modes:
        compare(args.capture_dir, mode, expected)
    for mode in ("thermal_trace", "headless_structure"):
        before = read_cases(args.capture_dir / f"before-{mode}.jsonl")
        after = read_cases(args.capture_dir / f"after-{mode}.jsonl")
        if before.keys() != after.keys() or len(before) != 5:
            raise ValueError(f"{mode}: expected five identical replay IDs")
        if args.thermal_scalability and mode == "thermal_trace":
            # Phase 3.4.1 can refresh material coefficients at a different
            # boundary. Verify the two backends at the same invalidation policy.
            fallback = read_cases(args.capture_dir / "fallback-thermal_trace.jsonl")
            if after != fallback:
                raise ValueError("Phase 3.4.1 native and GDScript thermal replays differ")
            changed = [case for case in before if before[case] != after[case]]
            print(f"{mode}: five identical native/fallback replays; baseline differs in {len(changed)} cases")
            continue
        if before != after:
            raise ValueError(f"{mode}: replay mismatch")
        print(f"{mode}: all {len(before)} replays identical")
    deep = [args.capture_dir / f"deep-{backend}.jsonl" for backend in ("baseline", "native", "gdscript")]
    if all(path.exists() for path in deep):
        baseline, native, gdscript = map(read_cases, deep)
        if baseline != native or baseline != gdscript or len(baseline) != 5:
            raise ValueError("Regional thermal replay mismatch")
        print("regional thermal trace: all five cases identical across both backends and baseline")


if __name__ == "__main__":
    main()
