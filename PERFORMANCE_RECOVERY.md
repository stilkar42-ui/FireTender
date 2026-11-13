# Firetender · Phase 3.3.2 performance recovery

The baseline is `ff8f3c7fddc7c31574a06fecc52725402468ac85`. Hardware, engine, fixture conventions, and the original matrix are in [the performance investigation](PERFORMANCE_INVESTIGATION.md). Stage comparisons use the i5-7500 and GTX 1070 Ti, Godot 4.7.2 Compatibility, dummy audio, uncapped 1920×1016 window, and the same benchmark script on both builds.

## Stage 1 · Support and gravity

The support pass still visits pieces in existing tier and rest order. Its expensive seat fit is reused when the piece’s seating inputs, nearby coal footprints, and ordered potential supports match the previous pass. Changes in position, profile, bearing condition, or support order invalidate dependent fits as the pass travels upward. The prior pose remains available to the original fall and roll logic. Loads are still recalculated in reverse order using the existing algorithm. This keeps the effect of wetness, changing mass, contact redistribution, and crushing thresholds.

Each rendered control seeds the same dense pile of 100 pieces, nine drying logs, and an active flame. It performs one action after two fixed steps and observes the following frames for a total of four seconds.

| Action | Direct call ms, original → Stage 1 | P99 frame ms, original → Stage 1 | Worst frame ms, original → Stage 1 | Pieces airborne immediately |
| --- | ---: | ---: | ---: | ---: |
| Move top | 130 → 14 | 172 → 64 | 209 → 79 | 0 |
| Move middle | 122 → 89 | 179 → 113 | 214 → 132 | 9 |
| Remove bottom support | 122 → 56 | 197 → 82 | 198 → 98 | 4 |
| Rotate middle | 128 → 96 | 185 → 109 | 188 → 147 | 5 |
| Remove primary support, inducing collapse | 54 → 53 | 167 → 116 | 184 → 148 | 51 |

The headless replay compared 210 snapshots of poses, contacts, loads, crushed sections, airborne and rolling states and roll travel against the original. All values matched exactly at the JSON output precision. The collapse case went from 51 airborne pieces to 35 on the next tick and zero after the following tick in both builds. The direct collapse call still does substantial work because it changes the support of much of the pile. Four-second worst-frame and P99 values also include combustion and rendering.

Use the same fixture on both checkouts. The `structure` mode measures frame and action latency. The `headless_structure` mode writes the ordered structural snapshots for deterministic comparison.

```powershell
& $godot --path . --resolution 1920x1016 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$out/structure.jsonl" structure 4
& $godot --headless --path . --script res://tools/stockpile_benchmark.gd -- "$out/structure-trace.jsonl" headless_structure
```
