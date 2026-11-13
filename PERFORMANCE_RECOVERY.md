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

## Stage 2 · Thermal-network construction

The network sorts regions along one axis and safely discards pairs outside the largest possible reach, the existing height limit, or the same-piece exclusion. Surviving pairs go through the original detailed checks in original index order. A grid bounds the small set of logs that can cover the midpoint used by the existing radiation model. Flame and airflow rays first screen whole-log bounds and keep the original segment contact test for survivors. The broad phase does not change distance limits or the link equations. Near-hearth promotion and cold storage retain their existing policy.

| 1920×1016 profile, 4-second captures | 60/9 dense flame, original → recovery | 100/9 loose scorch, original → recovery | 60/9 near-fire expansion, original → recovery |
| --- | ---: | ---: | ---: |
| Nodes | 89 → 89 | 89 → 89 | 243 → 243 |
| Candidate pairs sent to detailed checks | 3,916 → 617 | 3,916 → 723 | 29,403 → 7,054 |
| Accepted exchange and radiation links | 519 → 519 | 583 → 583 | 6,656 → 6,656 |
| Builds / fixed steps | 3 / 16 → 3 / 16 | 3 / 16 → 3 / 16 | 3 / 11 → 3 / 13 |
| Builds per wall second | 0.75 → 0.75 | 0.75 → 0.75 | 0.68 → 0.75 |
| Mean network construction | 23.9 → 17.4 ms | 28.2 → 19.0 ms | 574.6 → 273.1 ms |
| Mean inclusive simulation step | 23.4 → 17.2 ms | 28.6 → 22.9 ms | 201.1 → 106.3 ms |
| Maximum inclusive simulation step | 55.7 → 29.0 ms | 67.9 → 44.8 ms | 618.9 → 318.5 ms |
| Mean scoped visibility work per build | 7.2 → 1.2 ms | 8.4 → 1.5 ms | 268.1 → 47.1 ms |
| Worst rendered frame | 79 → 46 ms | 96 → 67 ms | 668 → 366 ms |

`thermal_trace` replayed 160 quarter-second steps from five matching fixtures and compared temperatures, moisture, combustible mass, flame, radiation, oxygen, link coefficients and link order once per simulated second. All five output hashes matched exactly. The coal control stayed unlit and the cold cabin ignited from a hand-placed ember in a prepared tinder bundle, reaching 14.05 kW in both builds. An intermediate cache version reused a valid seat while leaving worn upper-face coordinates stale. The final version refreshes active thermal coordinates on cache hits, restoring the exact flame and scorch traces.

## Woodpile baseline failures

The five failures reproduced before any source changes. Chapter I has 25 opening pieces, including four leaves for the tinder-bundle lesson. The existing test counted the earlier 21. That stale total also appeared at departure and as an assumed total of 29 after the eight-piece ridge trip, including in both material-preservation assertions. Phase 3.3 continues to deliver eight pieces in that route and now records individual field IDs at pickup. The revised assertions verify the seven opening stock types, unchanged shelter and field counts at departure, the field debit at pickup, eight distinct delivered pieces, and the original identity and material checks on placement and return.
