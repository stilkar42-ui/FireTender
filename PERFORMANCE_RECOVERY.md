# Firetender · Phase 3.3.2 performance recovery

The baseline is `ff8f3c7fddc7c31574a06fecc52725402468ac85`. Support is isolated in `fad445a` and the thermal stage in `16126b1` on `codex/phase-3.3.2-performance`. Hardware, engine, fixture conventions, and the original matrix are in [the performance investigation](PERFORMANCE_INVESTIGATION.md). Stage comparisons use the i5-7500 and GTX 1070 Ti, Godot 4.7.2 Compatibility, dummy audio, uncapped 1920×1016 window, and the same benchmark script on both builds.

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

The headless replay compared 210 snapshots of poses, contacts, loads, crushed sections, airborne and rolling states and roll travel against the original. All values matched exactly at the JSON output precision on both the support checkpoint and the final build. The collapse case went from 51 airborne pieces to 35 on the next tick and zero after the following tick in both builds. The direct collapse call still does substantial work because it changes the support of much of the pile. Four-second worst-frame and P99 values also include combustion and rendering.

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

`thermal_trace` replayed 160 quarter-second steps from five matching fixtures and compared temperatures, moisture, combustible mass, flame, radiation, oxygen, link coefficients and link order once per simulated second. All five output hashes matched exactly. The coal-only control sustained no flame and the cold cabin ignited from a hand-placed ember in a prepared tinder bundle, reaching 14.05 kW in both builds. An intermediate cache version reused a valid seat while leaving worn upper-face coordinates stale. The final version refreshes active thermal coordinates on cache hits, restoring the exact flame and scorch traces.

## Woodpile baseline failures

The five failures reproduced before any source changes. Chapter I has 25 opening pieces, including four leaves for the tinder-bundle lesson. The existing test counted the earlier 21. That stale total also appeared at departure and as an assumed total of 29 after the eight-piece ridge trip, including in both material-preservation assertions. Phase 3.3 continues to deliver eight pieces in that route and now records individual field IDs at pickup. The revised assertions verify the seven opening stock types, unchanged shelter and field counts at departure, the field debit at pickup, eight distinct delivered pieces, and the original identity and material checks on placement and return.

The revised woodpile suite passes 26 checks. Construction, cold builds, thermal, grain fractures, gathering and after-storm drying, and the full Chapter I–III journey also pass. The rendered valley, workbench, general scene, and after-storm suites passed with the Compatibility renderer.

## Repeating the performance regression

Use the same Godot version, window, audio driver, refresh settings and duration on both builds. Run one renderer at a time. For trends, repeat each run several times and compare medians.

```powershell
& $godot --path . --resolution 1920x1016 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$out/regression.jsonl" regression 4
& $godot --headless --path . --script res://tools/stockpile_benchmark.gd -- "$out/thermal-trace.jsonl" thermal_trace
py -3 tools/summarize_stockpile.py $out
```

The compact suite covers 20 stored pieces and six wet logs, 100 stored pieces and nine scorching logs, a dense pile move, an induced collapse, promotion near the fire and both accelerated settings. The full `matrix` mode keeps the original Phase 3.3.1 grid. The optional `--full-trace` argument writes sampled thermal states alongside their hashes.

## Final gameplay and fast-forward

| 1920×1016, matched three-second controls | Avg FPS, original → recovery | P99 frame ms, original → recovery | Worst frame ms, original → recovery | Sim s/s, original → recovery |
| --- | ---: | ---: | ---: | ---: |
| 60/9 dense flame, 1× | 64 → 68 | 82 → 40 | 101 → 42 | 0.98 → 0.99 |
| 100/9 loose scorch, 1× | 49 → 47 | 91 → 68 | 100 → 70 | 0.98 → 0.99 |
| 100/9 dense, repeatedly move one log | 8 → 28 | 351 → 153 | 351 → 153 | 0.58 → 0.90 |
| 60/9 near-fire promotion, 1× | 30 → 31 | 664 → 348 | 666 → 348 | 0.66 → 0.83 |
| 60/9 dense flame, 16× | 27 → 30 | 83 → 51 | 83 → 51 | 6.66 → 7.42 |
| 60/9 dense flame, 64× | 26 → 29 | 90 → 59 | 90 → 59 | 6.58 → 7.37 |

The repeated dense move’s direct P95 fell from **132 ms to 59 ms**. The near-fire expansion remains a visible hitch. At 100/9 scorching the frame tail improved and the 60 FPS average target remains unmet in the three-second capture.

In the 100/9 coal-bed matrix at 16×, the improvement was **10.52 → 13.91 sim s/s**, or **42.1 → 55.6 steps/s**. At 64× that case measured **14.63 → 13.02 sim s/s** despite an improved P99 of 71 → 53 ms. Dense flame profiling averaged roughly 18 ms per fixed step at both accelerated settings, well above the 8.5 ms scheduler budget. The harness continued to request 64 and 256 steps/s respectively. The fixed quarter-second model, per-frame budget and acceleration rendering cadence are retained. Improving those dense cases further requires additional per-step savings. Frame time and throughput respond differently when a frame completes only one long step.

The full coal-bed grid uses 2.5 seconds per case at each resolution, with the same dimensions, settings and fixture as Phase 3.3.1. [Post-optimization matrix](outputs/performance-3.3.2/matrix.md) · [Combined measurements](outputs/performance-3.3.2/results.csv) · [P99 scaling chart](outputs/performance-3.3.2/frame-time-p99.svg)

### Remaining frame pacing

The eight-second repeat measured 67 FPS / 39 ms P99 with the dense flame running. Pausing measured 69 FPS / 25 ms P99. Freezing the 3D viewport while leaving the simulation live measured 118 FPS / 32 ms P99. In the scorching repeat, the same stock measured 52 FPS / 52 ms P99. These results show headroom in the rendered and visual-script workload and meaningful variation across the short runs. The Compatibility viewport’s measured GPU work was about 3.1 ms in the live repeats. In the four-second scorch profile, `_refresh()` averaged 7.7 ms per call, compared with 7.1 ms on baseline. That includes steam, log parameters and ambient updates. The scope does not establish that changing painted shaders or making meshes less detailed would address the remaining stalls.

In the matching uninstrumented headless loop, the dense flame advanced **9.31 → 11.95 sim s/s** and the scorch case **8.64 → 10.34**. The worst near-pile step was still **464 ms**, down from **854 ms**. Large active graphs still perform thousands of accepted exchange and plume relationships. The played scene also pays for 3D work, procedural audio and the UI. The profiling supports further investigation of per-link plume and airflow work and cached static visual updates. The art assets and renderer were retained for this build.

## Playtest build

Open [Firetender.exe](outputs/performance-3.3.2/Playtest/Firetender.exe) with its adjacent PCK and `_sc_` marker. This local build uses the bundled Godot 4.7.2 runtime and an isolated profile folder. Start a game from the launch page, then use **F7** in the workbench for Chapter II practice. The compiled pack was smoke-tested with the Compatibility renderer.

## Full benchmark matrix

### 1920×1016

#### 1× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.16 | 7.50 | 13.59 | 15.45 | 17.50 | 122.54 | 1.00 | 3.99 |
| 0 | 3 | 9.05 | 8.25 | 14.65 | 16.34 | 18.01 | 110.55 | 1.00 | 3.99 |
| 0 | 6 | 9.24 | 8.40 | 15.13 | 18.31 | 19.60 | 108.23 | 0.99 | 3.98 |
| 0 | 9 | 10.14 | 9.05 | 15.57 | 19.68 | 24.59 | 98.61 | 1.00 | 3.99 |
| 20 | 0 | 8.77 | 8.00 | 14.32 | 16.39 | 17.76 | 114.06 | 1.00 | 3.99 |
| 20 | 3 | 9.13 | 8.36 | 14.52 | 15.83 | 16.50 | 109.51 | 1.00 | 4.00 |
| 20 | 6 | 9.81 | 8.91 | 15.52 | 16.88 | 22.54 | 101.93 | 1.00 | 3.98 |
| 20 | 9 | 10.51 | 9.37 | 16.11 | 21.74 | 24.62 | 95.19 | 1.00 | 4.00 |
| 40 | 0 | 9.20 | 8.46 | 14.91 | 15.53 | 22.09 | 108.65 | 1.00 | 3.99 |
| 40 | 3 | 9.95 | 9.06 | 15.64 | 19.12 | 24.80 | 100.53 | 1.00 | 3.99 |
| 40 | 6 | 10.93 | 9.87 | 16.38 | 22.35 | 26.71 | 91.47 | 1.00 | 3.99 |
| 40 | 9 | 12.09 | 10.73 | 18.53 | 22.39 | 33.81 | 82.68 | 0.99 | 3.98 |
| 60 | 0 | 9.81 | 8.96 | 15.55 | 18.74 | 26.75 | 101.89 | 0.90 | 3.60 |
| 60 | 3 | 10.34 | 9.43 | 15.72 | 20.75 | 21.64 | 96.71 | 1.00 | 4.00 |
| 60 | 6 | 11.17 | 10.11 | 17.22 | 23.64 | 25.40 | 89.50 | 1.00 | 4.00 |
| 60 | 9 | 11.59 | 10.48 | 17.26 | 26.57 | 31.37 | 86.30 | 0.90 | 3.60 |
| 100 | 0 | 10.98 | 9.89 | 16.83 | 26.86 | 31.83 | 91.06 | 0.99 | 3.98 |
| 100 | 3 | 11.71 | 10.50 | 17.38 | 29.18 | 34.59 | 85.43 | 1.00 | 3.99 |
| 100 | 6 | 12.49 | 11.09 | 18.34 | 31.33 | 38.05 | 80.06 | 1.00 | 3.98 |
| 100 | 9 | 12.99 | 11.52 | 19.20 | 35.13 | 36.07 | 76.98 | 1.00 | 3.99 |

#### 16× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.09 | 7.48 | 13.56 | 14.96 | 16.30 | 123.55 | 15.99 | 63.97 |
| 0 | 3 | 9.45 | 9.17 | 15.74 | 16.79 | 20.41 | 105.85 | 15.88 | 63.51 |
| 0 | 6 | 13.61 | 12.77 | 21.86 | 24.60 | 24.86 | 73.50 | 15.88 | 63.51 |
| 0 | 9 | 17.25 | 15.44 | 25.83 | 30.06 | 31.97 | 57.98 | 15.88 | 63.54 |
| 20 | 0 | 12.87 | 11.18 | 19.88 | 26.27 | 28.12 | 77.72 | 15.94 | 63.77 |
| 20 | 3 | 16.30 | 14.97 | 24.32 | 27.03 | 61.18 | 61.33 | 15.93 | 63.72 |
| 20 | 6 | 16.93 | 15.91 | 27.76 | 30.84 | 31.86 | 59.07 | 15.97 | 63.86 |
| 20 | 9 | 18.53 | 17.81 | 26.09 | 29.33 | 30.57 | 53.98 | 15.89 | 63.58 |
| 40 | 0 | 10.56 | 8.90 | 16.51 | 23.00 | 23.76 | 94.72 | 15.99 | 63.94 |
| 40 | 3 | 12.85 | 11.36 | 20.17 | 24.91 | 26.77 | 77.83 | 15.87 | 63.46 |
| 40 | 6 | 15.64 | 13.67 | 24.90 | 26.32 | 30.42 | 63.95 | 15.79 | 63.15 |
| 40 | 9 | 21.05 | 21.18 | 29.87 | 32.44 | 33.56 | 47.50 | 15.87 | 63.47 |
| 60 | 0 | 11.40 | 9.26 | 19.00 | 25.17 | 26.82 | 87.69 | 15.94 | 63.78 |
| 60 | 3 | 14.74 | 11.57 | 27.70 | 31.97 | 35.89 | 67.84 | 15.96 | 63.85 |
| 60 | 6 | 18.18 | 15.50 | 30.20 | 31.49 | 34.88 | 55.02 | 15.95 | 63.79 |
| 60 | 9 | 25.86 | 25.48 | 39.02 | 40.04 | 40.04 | 38.67 | 15.85 | 63.39 |
| 100 | 0 | 14.32 | 10.39 | 30.90 | 31.97 | 33.43 | 69.83 | 15.96 | 63.85 |
| 100 | 3 | 24.37 | 21.89 | 45.91 | 47.58 | 48.02 | 41.03 | 15.93 | 63.74 |
| 100 | 6 | 26.67 | 24.75 | 42.17 | 43.63 | 43.63 | 37.49 | 15.85 | 63.42 |
| 100 | 9 | 34.25 | 31.08 | 48.15 | 56.62 | 56.62 | 29.19 | 13.91 | 55.63 |

#### 64× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 9.60 | 8.91 | 18.62 | 20.45 | 31.88 | 104.20 | 36.23 | 144.92 |
| 0 | 3 | 11.77 | 8.47 | 22.32 | 23.77 | 29.39 | 84.97 | 36.40 | 145.61 |
| 0 | 6 | 21.45 | 20.27 | 28.42 | 30.10 | 33.01 | 46.62 | 31.18 | 124.73 |
| 0 | 9 | 24.57 | 23.53 | 34.11 | 36.48 | 36.87 | 40.70 | 20.25 | 81.00 |
| 20 | 0 | 11.07 | 9.69 | 19.52 | 24.80 | 26.26 | 90.31 | 36.26 | 145.06 |
| 20 | 3 | 17.02 | 19.58 | 27.01 | 31.50 | 34.71 | 58.75 | 36.47 | 145.87 |
| 20 | 6 | 22.99 | 22.45 | 29.80 | 31.64 | 35.35 | 43.50 | 26.84 | 107.35 |
| 20 | 9 | 24.70 | 24.57 | 31.29 | 32.78 | 34.62 | 40.49 | 20.14 | 80.58 |
| 40 | 0 | 14.08 | 10.30 | 26.02 | 31.28 | 35.05 | 71.01 | 36.20 | 144.82 |
| 40 | 3 | 26.54 | 25.65 | 33.33 | 38.05 | 38.05 | 37.67 | 36.19 | 144.74 |
| 40 | 6 | 22.33 | 21.37 | 28.17 | 29.09 | 31.13 | 44.79 | 22.30 | 89.19 |
| 40 | 9 | 27.87 | 28.18 | 39.10 | 45.70 | 45.70 | 35.88 | 17.84 | 71.36 |
| 60 | 0 | 18.38 | 21.04 | 29.02 | 29.98 | 30.04 | 54.39 | 36.29 | 145.18 |
| 60 | 3 | 29.94 | 29.34 | 36.01 | 44.12 | 44.12 | 33.40 | 29.82 | 119.29 |
| 60 | 6 | 24.68 | 24.07 | 30.84 | 33.95 | 34.60 | 40.52 | 20.26 | 81.05 |
| 60 | 9 | 30.53 | 31.97 | 40.85 | 42.86 | 42.86 | 32.75 | 16.08 | 64.31 |
| 100 | 0 | 32.55 | 31.36 | 41.43 | 44.60 | 44.60 | 30.72 | 30.42 | 121.67 |
| 100 | 3 | 37.60 | 39.38 | 45.99 | 49.15 | 49.15 | 26.60 | 22.33 | 89.32 |
| 100 | 6 | 29.84 | 30.46 | 42.99 | 47.27 | 47.27 | 33.51 | 16.45 | 65.82 |
| 100 | 9 | 35.42 | 32.36 | 50.85 | 53.27 | 53.27 | 28.23 | 13.02 | 52.09 |

### 1152×738

#### 1× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.88 | 8.02 | 14.47 | 18.54 | 18.66 | 112.55 | 1.00 | 3.99 |
| 0 | 3 | 9.08 | 8.31 | 14.93 | 16.14 | 19.16 | 110.15 | 1.00 | 3.99 |
| 0 | 6 | 9.34 | 8.54 | 14.89 | 16.76 | 18.11 | 107.11 | 1.00 | 4.00 |
| 0 | 9 | 10.17 | 9.18 | 15.66 | 19.64 | 21.05 | 98.36 | 1.00 | 3.98 |
| 20 | 0 | 8.74 | 8.00 | 14.36 | 15.27 | 16.29 | 114.38 | 1.00 | 3.99 |
| 20 | 3 | 9.44 | 8.61 | 14.87 | 16.46 | 19.67 | 105.98 | 1.00 | 3.98 |
| 20 | 6 | 9.91 | 8.94 | 15.39 | 17.08 | 22.34 | 100.91 | 1.00 | 3.99 |
| 20 | 9 | 10.77 | 9.66 | 17.21 | 18.38 | 24.20 | 92.84 | 1.00 | 3.98 |
| 40 | 0 | 10.51 | 9.77 | 17.87 | 19.37 | 20.29 | 95.10 | 1.00 | 4.00 |
| 40 | 3 | 10.17 | 9.13 | 15.74 | 18.50 | 26.59 | 98.30 | 1.00 | 4.00 |
| 40 | 6 | 11.80 | 10.66 | 19.37 | 22.71 | 28.42 | 84.76 | 1.00 | 4.00 |
| 40 | 9 | 11.64 | 10.36 | 17.74 | 22.89 | 24.79 | 85.93 | 1.00 | 4.00 |
| 60 | 0 | 10.06 | 9.20 | 16.15 | 19.86 | 26.42 | 99.43 | 1.00 | 3.99 |
| 60 | 3 | 11.29 | 10.11 | 17.14 | 21.96 | 24.99 | 88.56 | 1.00 | 3.99 |
| 60 | 6 | 11.18 | 10.14 | 16.51 | 22.98 | 29.96 | 89.45 | 1.00 | 3.99 |
| 60 | 9 | 12.40 | 10.86 | 18.58 | 26.86 | 33.65 | 80.67 | 0.99 | 3.97 |
| 100 | 0 | 11.46 | 10.41 | 17.16 | 26.86 | 35.18 | 87.28 | 1.00 | 3.99 |
| 100 | 3 | 12.50 | 11.05 | 18.71 | 28.41 | 32.39 | 79.97 | 1.00 | 4.00 |
| 100 | 6 | 12.59 | 11.31 | 18.46 | 32.46 | 41.45 | 79.44 | 1.00 | 3.99 |
| 100 | 9 | 13.53 | 12.08 | 19.44 | 40.11 | 41.51 | 73.88 | 1.00 | 3.99 |

#### 16× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.19 | 7.55 | 13.84 | 15.28 | 16.25 | 122.11 | 15.96 | 63.85 |
| 0 | 3 | 9.86 | 9.60 | 15.65 | 17.27 | 18.74 | 101.40 | 15.87 | 63.47 |
| 0 | 6 | 11.74 | 11.47 | 18.25 | 19.95 | 21.13 | 85.19 | 15.92 | 63.69 |
| 0 | 9 | 15.08 | 14.28 | 20.71 | 21.39 | 23.15 | 66.32 | 15.88 | 63.52 |
| 20 | 0 | 9.56 | 8.46 | 15.74 | 19.76 | 21.01 | 104.62 | 15.97 | 63.89 |
| 20 | 3 | 11.10 | 10.51 | 17.05 | 18.89 | 19.86 | 90.06 | 16.04 | 64.16 |
| 20 | 6 | 13.92 | 13.19 | 21.02 | 22.60 | 25.87 | 71.83 | 15.96 | 63.85 |
| 20 | 9 | 18.15 | 17.78 | 24.98 | 27.10 | 32.80 | 55.09 | 15.87 | 63.47 |
| 40 | 0 | 10.26 | 8.66 | 16.03 | 21.59 | 23.10 | 97.44 | 15.97 | 63.89 |
| 40 | 3 | 12.96 | 11.34 | 19.34 | 25.34 | 25.58 | 77.15 | 15.99 | 63.95 |
| 40 | 6 | 17.67 | 15.85 | 28.13 | 34.13 | 35.35 | 56.58 | 15.84 | 63.35 |
| 40 | 9 | 30.21 | 30.61 | 41.60 | 47.49 | 47.49 | 33.10 | 15.45 | 61.82 |
| 60 | 0 | 12.66 | 10.13 | 24.15 | 29.81 | 34.25 | 78.97 | 15.95 | 63.82 |
| 60 | 3 | 15.20 | 12.73 | 26.99 | 30.16 | 32.85 | 65.81 | 15.95 | 63.81 |
| 60 | 6 | 19.18 | 17.11 | 31.75 | 34.25 | 38.99 | 52.14 | 15.92 | 63.68 |
| 60 | 9 | 27.80 | 25.94 | 39.88 | 45.42 | 45.42 | 35.97 | 15.89 | 63.55 |
| 100 | 0 | 14.80 | 10.54 | 30.85 | 32.06 | 33.60 | 67.55 | 15.99 | 63.95 |
| 100 | 3 | 20.53 | 15.39 | 36.96 | 40.82 | 42.09 | 48.71 | 15.87 | 63.49 |
| 100 | 6 | 28.51 | 25.97 | 43.09 | 44.39 | 44.39 | 35.07 | 15.94 | 63.76 |
| 100 | 9 | 34.80 | 32.80 | 49.83 | 53.43 | 53.43 | 28.74 | 13.47 | 53.88 |

#### 64× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.24 | 7.77 | 13.17 | 15.52 | 30.47 | 121.40 | 36.24 | 144.96 |
| 0 | 3 | 11.92 | 8.00 | 24.32 | 26.70 | 39.44 | 83.92 | 36.46 | 145.85 |
| 0 | 6 | 20.25 | 18.93 | 26.77 | 28.52 | 38.63 | 49.38 | 36.73 | 146.94 |
| 0 | 9 | 21.59 | 20.34 | 27.38 | 30.11 | 37.57 | 46.31 | 23.06 | 92.23 |
| 20 | 0 | 10.08 | 8.19 | 17.67 | 20.21 | 32.42 | 99.18 | 36.29 | 145.17 |
| 20 | 3 | 16.59 | 19.37 | 26.98 | 27.93 | 43.71 | 60.29 | 36.43 | 145.72 |
| 20 | 6 | 22.14 | 21.60 | 29.06 | 30.19 | 35.51 | 45.16 | 29.67 | 118.70 |
| 20 | 9 | 24.85 | 24.27 | 31.95 | 35.32 | 38.01 | 40.24 | 20.02 | 80.08 |
| 40 | 0 | 13.10 | 8.22 | 27.13 | 32.35 | 35.83 | 76.32 | 36.26 | 145.05 |
| 40 | 3 | 26.89 | 25.71 | 33.13 | 38.66 | 38.66 | 37.19 | 36.09 | 144.38 |
| 40 | 6 | 21.87 | 20.50 | 28.57 | 29.35 | 30.60 | 45.72 | 22.76 | 91.04 |
| 40 | 9 | 27.19 | 27.79 | 36.38 | 44.44 | 44.44 | 36.78 | 18.29 | 73.16 |
| 60 | 0 | 18.94 | 21.11 | 28.90 | 32.82 | 34.67 | 52.79 | 36.29 | 145.18 |
| 60 | 3 | 30.44 | 29.03 | 36.70 | 39.53 | 39.53 | 32.85 | 32.16 | 128.64 |
| 60 | 6 | 24.73 | 24.38 | 31.10 | 33.41 | 34.39 | 40.44 | 20.22 | 80.88 |
| 60 | 9 | 30.98 | 32.03 | 40.97 | 50.35 | 50.35 | 32.28 | 15.84 | 63.36 |
| 100 | 0 | 31.25 | 29.26 | 37.24 | 44.36 | 44.36 | 32.00 | 31.70 | 126.79 |
| 100 | 3 | 35.73 | 36.75 | 45.24 | 46.40 | 46.40 | 27.99 | 22.89 | 91.55 |
| 100 | 6 | 31.27 | 30.61 | 46.91 | 56.20 | 56.20 | 31.98 | 15.99 | 63.96 |
| 100 | 9 | 34.40 | 31.18 | 55.31 | 58.39 | 58.39 | 29.07 | 11.85 | 47.39 |
