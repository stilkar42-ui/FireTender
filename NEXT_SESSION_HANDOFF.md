# Firetender engine handoff · November 20, 2026

## Completed

- Phase 3.3.2 made individual stored logs persistent, improved support fitting and rendering updates, and separated cold storage from the active hearth.
- Phase 3.4 moved ordered exchange, candidate pruning and support fitting into the Windows extension, with indexed wind and shielding queries and a GDScript fallback.
- Phase 3.4.1 added batched native graph construction. Finalization restored Phase 3.4’s coefficient sampling boundaries after tracing extra residue-driven resampling. Settling still reuses a graph when active geometry and coefficient inputs match.
- Bonfire work fixes repeated cave/camera invalidation caused by comparing a float vector component with a double depth. Camera movement refreshes billboards without reapplying every log’s mesh and material state. Placement now allows 128 active pieces. Section fracture partitions existing material regardless of the total active piece count, and native construction accepts up to 2048 thermal nodes.

## Current architecture and verification

- `sim/fire.gd` owns physical state and the fixed 0.25 s step. The extension builds ordered links and evaluates exchange from packed buffers. GDScript handles combustion, moisture, wear, structure and story, and can build and solve the full graph with `--reference-fire`.
- Version 5 saves store the ordered thermal links as packed binary64 rows and compress the checksummed state. This preserves sampled coefficients while fitting a large bonfire into a normal save. The 128-log capacity test has 1033 thermal nodes and writes a 5.7 MB save from a 25.8 MB state. Versions 1–4 still load, including uncompressed files and object-based links.
- All five thermal replays matched Phase 3.4 and both backends exactly. All 210 structural snapshots matched. Native/GDScript comparisons matched 33 graph fixtures and 12 active save/reload snapshots. The final headless mass-promotion step peaked at 46.3 ms versus 606 ms at baseline. A rendered spot check measured 83.4 FPS at 60/6 coals, 71.3 FPS at 100/9 dense flame and 51.5 FPS at 150/12 scorching. See [performance results](PERFORMANCE_ARCHITECTURE_3_4_1.md).

## Bonfire verification

- Tests build 24-, 48- and 72-log fires beside 100 stored pieces. The rendered regression verifies camera updates at all three cave sites, 48 normal player placements, fracture and material conservation, save-slot writes, exact large-fire continuation and malformed-link rejection.
- The 72-log graph has 585 nodes and 65,241 links. Its original snapshot was 59.6 MB. Packed links reduce that state to 18.4 MB before file compression.
- The near-hearth replay now permits two fractures at 1112.00 and 1112.25 simulation seconds. The earlier global fragment cap suppressed both. This intentional structural correction changes its thermal digest. The other four baseline digests match. All five current native/fallback thermal digests match exactly, and all 210 baseline structural snapshots match.
- A prototype native axial-exchange batch failed to improve measured step time and was removed.

Matched captures against `phase-3.4.1-playtest` used the Compatibility renderer at 1920×1016. Bonfire cases ran for 10 seconds each. The 150-piece scorching repeat ran for 30 seconds. Regression processes had finished before these measurements.

| Case | FPS before → after | Frame P99 ms before → after |
|---|---:|---:|
| 24 burning logs + 100 stored | 50.6 → 65.9 | 58.3 → 55.7 |
| 48 burning logs + 100 stored | 28.1 → 49.5 | 98.3 → 86.6 |
| 72 burning logs + 100 stored | 20.6 → 45.6 | 131.6 → 110.0 |
| Orbit a 48-log fire | 32.7 → 42.8 | 51.6 → 43.9 |
| Repeatedly reposition its bottom log | 11.8 → 15.0 | 180.6 → 188.2 |
| Chapter II, 150 stored / 12 scorching | 50.8 → 71.4 | 70.4 → 57.2 |

The promotion fixture’s largest frame fell from 156.7 to 142.8 ms in this run. Large active piles still have substantial physics-step and manipulation stalls. The bottom-log replay places the support every 140 ms and repeatedly disturbs its stack. Rendering gains do not remove those simulation costs.

The targeted checks passed for combustion, thermal construction, grain, rolling, woodpiles, construction, physical work, profiles, the full Chapter I–III journey and the 126-assertion workbench suite. The Red Hollow scene suite reproduced its four known failures. The bonfire regression also verifies that geometry changes refresh picking and placement previews after idle camera updates were removed.

## Next engine work

- Trace the remaining 149–151 ms rendered promotion spike and sustained combustion cost with matched, correlated simulation, main-thread, render submission, GPU synchronization and frame pacing measurements. The ~19 ms graph rebuild accounts for only part of the spike. Also measure interiors, moisture, wear and surface reactions during sustained scorching.
- The one-minute 150-piece / 12-log scorching case averaged 52.4 FPS in the prior capture. Actual rendered medians at requested 16× and 64× were 10.87× and 10.42×. Keep fixed simulation steps.
- Four baseline Red Hollow scene assertions still fail. They cover opening pile picking, returning a log to the pile, the returning scout’s delivery and talking to him with another tool selected.
- Treat 24–48 full logs as the current bonfire performance target. The 72-log case remains a stress workload. Measure sustained reaction, internal moisture and section-summary costs before choosing the next native operation. The 128-log test verifies functional capacity, native construction and saving.
- Playtest Chapter II with a large reserve, active flame and twelve drying logs. Move a remote log and a near-hearth log, pull a support from a bonfire, bank and expose coals, then check save/reload and entry to Chapter III. For a packaged save, use an empty slot and leave occupied slots intact.

## Repository and builds

The annotated tag `phase-3.4.1-playtest` identifies the mainline release commit. Resolve it with `git rev-parse phase-3.4.1-playtest^{commit}`. Use the merge commit to review the development history after branch cleanup. [PR #2 history](https://github.com/stilkar42-ui/FireTender/pull/2)

The playtest package is at `outputs/finalization-3.4.1/Firetender-Phase-3.4.1-Windows.zip`. Its build manifest records the exact mainline commit.

Current engine development is on `codex/bonfire-performance`, based on `e284607`. Benchmark captures and regression logs are under `outputs/bonfire-performance`.

The current Windows preview is at `outputs/bonfire-performance/Firetender-Bonfire-Preview-Windows.zip`. It includes a build manifest, the original Chapter II stress save and separate 24- and 72-log bonfire fixtures. Version 5 saves require this build or a newer compatible build.
