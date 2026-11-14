# Firetender Phase 3.4.1 · Thermal network scalability

Baseline `5cb24a95794a7d700bdd76530d907f021bc6048e`. Development branch `codex/phase-3.4-performance`. [Echo’s review on Draft PR #2](https://github.com/stilkar42-ui/FireTender/pull/2#pullrequestreview-5901661164)

## Invalidation and construction

- Structural settling compares the ordered active wood, faces and coals against the geometry consumed by the graph. This includes identity, pose, contact radius, occluder dimensions, airflow eligibility and static material inputs. Stored pieces still participate in structural supports and wind. They enter the thermal graph through the existing promotion and spark rules.
- Changes to active membership, coal placement or footprint, and active support or section geometry invalidate the graph. Coal residue and ash handling can also invalidate sampled coefficients. The material check follows the existing combustion settling cadence for wear, with live per-step capacities and insulation. In-flight gravity and sectional fracture still pass through the existing structural solver.
- The Windows extension reuses the ordered broad-phase candidates. It builds the same radiation and airflow grid, evaluates the starter vents and accepted edges in bulk, accumulates node loads in candidate order, normalizes the links, and returns packed exchange rows. Geometry uses standard-precision Godot vector arithmetic. Coefficients and accumulators remain binary64. The closest-point solver follows Godot’s segment implementation. [Godot 4.7.2 geometry source](https://github.com/godotengine/godot/blob/4.7.2-stable/core/math/geometry_3d.cpp#L32-L123)
- Native exchange reads the packed rows directly. GDScript materializes Link objects for the few fibre or coal-bed edges it processes, and for the save and fallback paths when needed. Story saves still use version 4 with the original link representation.
- The implementation rebuilds the complete graph after invalidation. Midpoint occlusion, plume rays, crowding and shared outgoing-energy totals can all change links whose endpoints stay fixed. The measured construction time makes incremental topology a poor trade for this phase. The remaining rendered spike includes substantial work outside construction.

## Construction profile

The Windows test machine has an Intel i5-7500, 16 GB RAM and a GeForce GTX 1070 Ti. Godot 4.7.2 used the Compatibility renderer with the same 1920×1016 window and 1549×820 scene raster. The placement fixture moves one hot log near a cold pile and grows the active population from 6 to 68. The 24-step headless run produced three graph rebuilds and finished with 354 nodes, 14,720 broad-phase candidates and 14,143 accepted links.

The following costs are totals over the three rebuilds from disposable projects with probes enabled. The detailed GDScript probes add timing overhead per pair. Nested rows overlap. These totals describe where time goes. The uninstrumented benchmark below measures player-facing time.

| Construction work | Phase 3.4 total, ms | Phase 3.4.1 total, ms |
|---|---:|---:|
| Complete graph rebuilds | 2557.2 | 54.7 |
| Broad phase and candidate conversion | 10.6 | Included in rebuild |
| Native candidate bridge call | 5.6 | Included in rebuild |
| Starter vent passages | 86.2 | Included in native batch |
| Accepted and rejected pair traversal | 2317.4 | Included in native batch |
| Solid-contact geometry | 148.6 | Included in native batch |
| Conductance and loads, including contact | 339.2 | Included in native batch |
| Flame coefficients and air paths | 431.0 | Included in native batch |
| Ember feedback | 19.9 | Included in native batch |
| Radiation visibility and view factors | 599.4 | Included in native batch |
| Radiation visibility alone | 425.2 | Included in native batch |
| Crowding and shielding | 99.1 | Included in native batch |
| Per-node normalization and link normalization | 83.8 | Included in native batch |
| Link allocation and initial fields | 225.1 | Packed by native batch |
| Exchange link packing | 72.5 | Packed by native batch |
| Geometry and occluder input packing | — | 5.9 |
| Native construction call including transfer | — | 17.7 |
| Native exchange calls over 24 steps | 4.0 | 3.9 |

The final 354-node rebuild took 805.8 ms with detailed GDScript probes and 19.1 ms with native construction. The optimized rebuilds included the mass promotion and two subsequent increases in coal-patch count. Before native construction, the isolated invalidation stage improved a matched 10-second remote log interaction from 72.0 to 80.0 FPS, frame P95 from 28.0 to 24.3 ms, and P99 from 40.3 to 31.1 ms. Its matched 24-step headless mean went from 10.86 to 9.11 ms. The dedicated invalidation checks verify graph reuse directly.

## Rendered Chapter II

Six seconds per case, same fixture and runtime on both builds. FPS is total frames divided by elapsed wall time. P95 and P99 are individual frame durations.

| Stored / drying | Condition | FPS before → after | P95 ms before → after | P99 ms before → after |
|---|---|---:|---:|---:|
| 60 / 6 | Coals | 86.6 → 106.7 | 19.1 → 14.7 | 24.8 → 17.7 |
| 60 / 6 | Dense flame | 77.8 → 88.6 | 20.7 → 17.5 | 29.9 → 25.7 |
| 60 / 6 | Scorching | 69.4 → 86.3 | 22.9 → 17.8 | 34.5 → 27.2 |
| 100 / 9 | Coals | 76.6 → 91.6 | 21.3 → 16.4 | 37.8 → 29.1 |
| 100 / 9 | Dense flame | 79.0 → 79.7 | 18.6 → 20.1 | 35.4 → 33.8 |
| 100 / 9 | Scorching | 68.4 → 64.6 | 22.4 → 25.9 | 45.6 → 52.8 |
| 150 / 12 | Coals | 63.2 → 66.7 | 25.0 → 23.7 | 53.4 → 47.7 |
| 150 / 12 | Dense flame | 62.7 → 69.3 | 26.4 → 23.0 | 55.9 → 52.5 |
| 150 / 12 | Scorching | 44.7 → 48.6 | 38.6 → 40.5 | 151.8 → 69.3 |

| Interaction | FPS before → after | P95 ms before → after | P99 ms before → after |
|---|---:|---:|---:|
| Move a remote cold log | 74.2 → 77.9 | 27.7 → 25.4 | 38.8 → 36.3 |
| Reposition a drying log | 57.8 → 65.6 | 38.7 → 31.6 | 55.7 → 42.9 |
| Move a log near the hearth | 35.7 → 54.4 | 73.6 → 47.1 | 99.7 → 61.9 |
| Remove a supporting piece | 65.7 → 70.1 | 24.3 → 22.1 | 59.7 → 45.1 |
| Induce stack collapse | 71.8 → 72.9 | 20.8 → 20.4 | 48.9 → 55.2 |

| Promotion | Phase 3.4 | Phase 3.4.1 |
|---|---:|---:|
| Peak rendered frame, 10-second case | 634.3 ms | 149.0 ms |
| Rendered frame P99 | 72.2 ms | 54.5 ms |
| Slowest headless step | 606.4 ms | 42.5 ms |
| Mean headless step | 93.8 ms | 25.7 ms |

An independent repeat measured 648.5 → 150.7 ms for the rendered promotion window and 591.1 → 46.6 ms for the slowest headless step. A frame-correlated probe measured 154.7 ms in a separate instrumented run. That frame spent 42.9 ms in the lab callback, including 42.6 ms advancing the story and 16.1 ms of graph construction inside the simulation step. The scene refresh and audio callbacks took 7.4 ms and 7.9 ms. The remaining wall time sits outside those sampled callbacks.

The 100/9 scorching fixture exceeded 60 FPS while its tail latency increased in this capture. The 150/12 scorching fixture and the 100 ms rendered promotion target remain open. The profile attributes up to 19 ms to construction and up to 51 ms to the simulation step in the rendered run. It recorded up to 8.7 ms for the scene refresh callback. These scopes leave part of the worst rendered frame unattributed. During dense promotion, the headless run averaged 15.3 ms for interiors and wear and 8.4 ms for surface reactions. Those costs continue after the graph is built.

The separate 60-second 150/12 scorching capture measured 56.7 → 52.4 FPS, frame P95 28.4 → 35.3 ms, P99 73.8 → 63.8 ms, and worst frame 213.9 → 105.7 ms. The optimized graph reduced the longest stalls even though sustained performance varied between the two captures.

## Acceleration

Median actual simulated seconds per wall-clock second across the nine stationary fixtures at each setting. The headless loop executes identical 0.25-second steps without the rendered clock or requested speed cap. The three headless rows are repeated throughput samples.

| Requested | Rendered before → after | Headless before → after |
|---|---:|---:|
| 1× | 1.00 → 1.00 | 13.86 → 17.11 |
| 16× | 9.60 → 10.87 | 13.71 → 17.36 |
| 64× | 9.76 → 10.42 | 13.47 → 17.04 |

## Numerical, save and regression results

- Native and GDScript matched exactly over 33 constructed graphs. The checks compared 32,749 ordered candidates, 31,761 accepted links, all normalized coefficients, starter ventilation and crowding. The fixtures include mass promotion, seeded stacks, fibre and tinder, parallel touch and near-touch, cell-border movement, worn radii and coal displacement. The measured maximum coefficient difference was zero.
- All five 160-step thermal digests matched between Phase 3.4.1 native and GDScript. The digest covers exposed and internal regions, moisture, mass, temperatures, heat fluxes and links. All 210 structural snapshots matched the reviewed commit. Four thermal digests differ from the reviewed commit under the new invalidation policy. Ignition times match in all five cases. Peak flame changed by +0.02804 kW in dense flame, +0.02847 kW in scorching, +0.02565 kW in near-hearth flame, and −0.00000266 kW in the ember ignition case. The coal-only case matched exactly. Neither comparison uses a tolerance.
- A binary save and reload during mass promotion followed by directed breath matched 12 complete snapshots across the two backends. The packaged renderer loaded the existing version 4 Chapter II stress save, retained all 166 pieces and advanced four fixed steps. The Windows DLL rebuilt twice with identical SHA-256 `58231ca676c08b214971dc7b72c05475a214fe501f2a33e71e555f11a32a6f5c`.
- 40 of 41 executable regression suites passed, including 46 combustion assertions, the two-hour replay, all 16 rendered Chapter I–III journey assertions and 33 story menu and profile assertions. The separate Red Hollow scene suite reproduced the four baseline failures involving opening pile picking, return to pile, the returning scout’s delivery and his conversation. It passed its other 14 assertions. The painted-world capture wrote all 11 views.

## Reproduction

```powershell
./native/build.ps1 -Godot $godot -Zig $zig
./tools/run_phase_34_benchmark.ps1 -Godot $godot -Reference 5cb24a9 -Destination ./outputs/performance-3.4.1/reproduction -ThermalScalability -Seconds 6
./tools/export_phase_34.ps1 -Godot $godot -WindowsTemplate $windowsTemplate -StressSave $stressSave -Version 3.4.1 -Destination ./outputs/performance-3.4.1/Windows-Playtest
```

Use Godot 4.7.2 standard-precision Windows x86-64 and Zig 0.15.2. For a construction profile, unpack a project copy, run `py -3 tools/instrument_stockpile.py <project-copy>`, import the copy, and run `res://tools/stockpile_benchmark.gd` in `headless_promotion` mode. Keep the probes outside the performance captures. Pass `--reference-fire` after the Godot user-argument delimiter to select GDScript.

The active placement guard `MAX_WOOD = 28` and fracture guard `MAX_WOOD + MAX_FRAGMENTS` still constrain larger hearth designs. Proximity promotion can exceed the placement cap, as it does in this fixture. Larger player-built hearths would need their own balance, placement and fracture review.
