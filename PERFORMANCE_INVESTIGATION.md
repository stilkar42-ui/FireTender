# Firetender · Phase 3.3.1 performance investigation

The support and thermal changes are measured in [Phase 3.3.2 performance recovery](PERFORMANCE_RECOVERY.md). This report records the original baseline.

## Build and hardware

Gameplay baseline `ff8f3c7fddc7c31574a06fecc52725402468ac85`, including the painted world and persistent gathering. The earlier comparison uses `398c5571cec969721174955112188044540a16f7`. The benchmark and probes are development tools. The production simulation, schedules, scenes, and shaders were left untouched.

| Component | Test configuration |
| --- | --- |
| CPU | Intel Core i5-7500 at 3.40 GHz, four logical processors |
| GPU | NVIDIA GeForce GTX 1070 Ti, 8 GiB VRAM, driver 560.94 |
| RAM / OS | 16 GiB installed, 15.96 GiB visible to Godot, Windows 10 Pro 22H2 (19045) |
| Runtime | Godot 4.7.2 stable official, OpenGL 3.3 Compatibility, source/debug run, dummy audio, VSync disabled, uncapped |
| Window and rendered area | 1920×1016 and 1152×738 windows. At 1×, Godot stretches from internal 3D areas of 1549×820 and 1280×820. At 16× and 64× the game normally uses 1053×558 and 870×558 respectively, with reduced refresh. |

## Reproduction

Use Chapter II practice with **F7**. Accumulate wood under cover, wake a substantial coal bed and place six to nine damp and wet medium or large logs just outside the ring. Check a loose pile in the back and a densely stacked pile, then move, turn, or reposition a log while the fire runs. The benchmark uses real model pieces, poses, regional moisture, thermal links and the production time scheduler. It seeds comparable coals and placements directly so that gathering variation and different player layouts do not determine the measurements. It tests heavier loads and an active flame separately from the stable coal matrix.

From PowerShell, set `$godot` to the Godot 4.7.2 executable and run the following.

```powershell
$report = Join-Path (Get-Location) 'outputs/performance-3.3.1'
New-Item -ItemType Directory -Force -Path $report | Out-Null
& $godot --path . --resolution 1920x1016 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$report/native.jsonl" matrix 2.5
& $godot --path . --resolution 1152x738 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$report/low.jsonl" matrix 2.5
& $godot --path . --resolution 1920x1016 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$report/controls.jsonl" controls 3.0
py -3 tools/summarize_stockpile.py $report
```

For function timings, use `git archive` to extract the baseline into a disposable folder, copy `tools/stockpile_benchmark.gd` there, and run `py -3 tools/instrument_stockpile.py <copy>` from this workspace. Import the copied project with Godot `--headless --editor --path <copy> --import` before launching it. Run the same benchmark with mode `profile` at 1920×1016, or use `--headless` with mode `headless` or `headless_controls`. The optional last argument is a case-ID regular expression. For example, `^060-9-01-flame-dense` restricts the instrumented run to the dense 60/9 flame and interaction cases. Keep the two Godot renders sequential so they do not share a GPU during collection.

To reproduce the paired render controls and earlier build, substitute the path of the disposable instrumented copy for `$profileCopy` and an imported archive of the earlier commit for `$prepaintCopy`. Put the same benchmark script in its `tools` directory.

```powershell
$case = '^060-9-01-flame-(dense-(normal|reduced|render_off)|near-normal)$'
& $godot --path "$profileCopy" --resolution 1920x1016 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$report/profile-repeat.jsonl" profile 8 $case
& $godot --path "$prepaintCopy" --resolution 1920x1016 --audio-driver Dummy --script res://tools/stockpile_benchmark.gd -- "$report/prepaint.jsonl" controls 3 '^(000-0-01-coal-loose-normal|060-9-(01|16)-(flame|scorch)-dense-normal|060-9-01-flame-dense-look_pile)$'
& $godot --headless --path . --script res://tools/stockpile_benchmark.gd -- "$report/headless-uninstrumented.jsonl" headless_controls 2 '^060-9-01-(coal-loose|flame-dense|flame-near)-normal$|^100-9-01-scorch-loose-normal$'
& $godot --path . --debug --profiling --gpu-profile --audio-driver Dummy --resolution 1920x1016 --script res://tools/stockpile_benchmark.gd -- "$report/godot-profiler.jsonl" controls 35 '^060-9-01-flame-dense-move$' *> "$report/godot-profiler.log"
```

The rendered fixture warms for about one second after scene assembly, then samples consecutive process-frame intervals and actual advancement of the fire clock for 2.5–4 seconds. It re-creates the same seeded scene for each case. Headless timing runs the same chapter steps without a renderer or frame budget. FPS uses sampled frames divided by elapsed wall time. Each simulation step advances one quarter-second, so 1×, 16× and 64× request 4, 64 and 256 steps per real second respectively.

## Raw measurements

- [Full frame-time and throughput matrix](outputs/performance-3.3.1/matrix.md) contains mean, median, P95, P99, maximum, FPS, simulated seconds per real second and steps per real second for each combination.
- [Combined CSV](outputs/performance-3.3.1/results.csv) includes the controls, scoped profiler times, memory and object counts.
- [P99 scaling graph](outputs/performance-3.3.1/frame-time-p99.svg)

Frame intervals include game script, renderer, transfers and Windows scheduling. Godot’s per-viewport render timers measure CPU submission and GPU work for the 3D subviewport. At reduced refresh the last GPU result can repeat on frames without a new 3D draw. Godot’s process monitor is a coarse engine reading. Opt-in scope timers supply the direct simulation and script costs. Inclusive times overlap and should not be added together. Candidate-rejection and visibility timers add instrumentation overhead, especially on small calls. Baseline FPS comes from uninstrumented runs.

## How much it slows down

In the 1920×1016 coal-bed sweep at 1×, going from an empty pile to 100 stored pieces and nine drying logs dropped average FPS from **119 to 74** and raised the 99th-percentile frame from **16 to 41 ms**. An active flame brings the same loaded scene to **59 FPS / 81 ms P99**. With nine wet logs already steaming or scorching it reaches **49 FPS / 91 ms P99**. The fire clock still keeps close to 1× in each of those cases. The player experiences interrupted input and camera motion while combustion continues to advance.

| 1920×1016, loose coal-bed cases | Request | Mean ms | Median ms | P95 ms | P99 ms | FPS | Sim s/s | Steps/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Empty | 1× | 8.38 | 7.68 | 13.96 | 16.24 | 119.3 | 1.00 | 3.99 |
| 40 stored, 9 drying | 1× | 11.04 | 10.06 | 16.91 | 21.92 | 90.6 | 0.90 | 3.60 |
| 60 stored, 9 drying | 1× | 11.95 | 10.78 | 18.05 | 25.12 | 83.7 | 1.00 | 3.99 |
| 100 stored, 9 drying | 1× | 13.57 | 12.25 | 19.62 | 41.12 | 73.7 | 1.00 | 3.98 |
| 60 stored, 9 drying | 16× | 38.68 | 39.43 | 50.58 | 64.17 | 25.8 | 12.63 | 50.5 |
| 100 stored, 9 drying | 16× | 36.00 | 30.95 | 53.86 | 77.36 | 27.8 | 10.52 | 42.1 |
| Empty | 64× | 12.64 | 10.86 | 19.87 | 31.35 | 79.1 | 36.26 | 145.0 |
| 60 stored, 9 drying | 64× | 29.39 | 30.27 | 40.34 | 48.82 | 34.0 | 16.71 | 66.8 |
| 100 stored, 9 drying | 64× | 33.50 | 36.20 | 47.21 | 71.08 | 29.9 | 14.63 | 58.5 |

At normal speed, the coal-bed tail rises gradually to about 25 ms around 60/9 and passes 33 ms at 100/9. With an active flame, the transition is earlier. At 60 stored pieces, adding six drying logs takes P99 from 30 to 50 ms. Going from six to nine takes it to 52 ms, or 60 ms in the steaming and scorching condition. Dense stacking increases the cost of support searches. Moving a piece in a dense 100-piece pile brings the game into a different range entirely.

| 1920×1016, 1× controls | Median ms | P95 ms | P99 ms | Worst ms | FPS | Sim s/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 60/0 loose, flame | 10.21 | 17.47 | 29.51 | 39.22 | 87.0 | 1.00 |
| 60/6 loose, flame | 11.10 | 19.33 | 49.81 | 53.92 | 76.5 | 1.00 |
| 60/9 loose, flame | 11.90 | 22.69 | 52.41 | 67.69 | 69.9 | 0.98 |
| 60/6 loose, scorching | 12.29 | 20.69 | 53.72 | 58.81 | 68.9 | 1.00 |
| 60/9 loose, scorching | 13.63 | 26.88 | 59.91 | 68.15 | 60.9 | 0.99 |
| 100/9 loose, flame | 13.56 | 25.77 | 80.56 | 98.35 | 59.3 | 0.98 |
| 100/9 loose, scorching | 16.18 | 43.07 | 91.11 | 99.75 | 49.1 | 0.98 |
| 60/9 dense, flame | 12.56 | 24.87 | 82.41 | 100.95 | 64.3 | 0.98 |
| 60/9 dense, scorching | 13.60 | 30.60 | 78.99 | 85.01 | 59.0 | 0.99 |
| 60/9 near the fire, flame | 15.97 | 61.82 | 663.70 | 665.72 | 30.2 | 0.66 |

The dense 60/9 flame ran at **27 FPS and 6.66 sim s/s** with 16× requested, and **26 FPS and 6.58 sim s/s** with 64× requested. Scorching controls reached roughly 6.4–6.5 sim s/s. At 64×, a greater share of frames can spend their entire budget on a single expensive step. The 8.5 ms wall-time budget in `hearth/lab.gd` can return only between fixed steps. It cannot preempt a long step. Render cadence, steps per frame, and the phase of periodic events all affect the short-run result at each speed.

## Thermal solver and stored fuel

The detail of a medium or large piece is preserved in these runs. The active network includes a log’s regional nodes plus the coals and any flaming starter wood. The quiet remote pile usually stays outside the network. The stress case uses the same count as 60/9 dense but moves the pile close enough to the hearth for **30 of its 60 pieces** to become active. The labels count placed stock. The measured stored and active columns show the resulting membership.

| Live state | Remote stored | Active wood | Thermal nodes | Candidate pairs | Exchange links | Positive conduction | Radiation links |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Coal bed only | 0 | 0 | 9 | 36 | 3 | 3 | 3 |
| Coal, 3 drying | 60 | 3 | 27 | 351 | 21 | 21 | 21 |
| Coal, 6 drying | 60 | 6 | 43 | 903 | 45 | 45 | 45 |
| Coal, 9 drying | 60 | 9 | 61 | 1,830 | 169 | 169 | 169 |
| Dense flame, 9 drying | 60 | 13 | 89 | 3,916 | 519 | 519 | 519 |
| Scorching, 9 drying | 100 | 13 | 89 | 3,916 | 583 | 583 | 583 |
| Near pile, 9 drying and 30 promoted | 30 | 43 | 243 | 29,403 | 6,656 | 6,656 | 6,656 |

Counts are representative rendered readings. The positive-conduction column counts final links with positive conductance in matching headless runs. An exchange link may also carry plume coupling.

| Godot scope in `sim/fire.gd` | 60/9 dense flame | 100/9 loose scorch | 60/9 near fire |
| --- | ---: | ---: | ---: |
| `step()` inclusive, mean / max | 23.38 / 55.67 ms | 28.62 / 67.87 ms | 201.05 / 618.95 ms |
| `_prepare_network()`, mean per build | 23.89 ms | 28.24 ms | 574.64 ms |
| Network builds / measured steps | 3 / 16 | 3 / 16 | 3 / 11 |
| All pair work, mean per build | 22.01 ms | 26.10 ms | 514.31 ms |
| Rejected pairs, mean per build | 3,397 | 3,333 | 22,747 |
| Rejections, estimated time per build | 3.58 ms | 3.83 ms | 26.37 ms |
| Visibility, estimated time per build | 7.19 ms | 8.42 ms | 268.06 ms |
| Active links, conduction and plume per step | 1.26 ms | 1.42 ms | 13.67 ms |
| Active links, radiation per step | 0.50 ms | 0.60 ms | 5.72 ms |
| Regional interiors, moisture and wear per step | 2.92 ms | 3.03 ms | 8.31 ms |
| Surface reaction per step | 2.06 ms | 2.71 ms | 5.13 ms |
| Smoke per step | 0.50 ms | 0.96 ms | 0.59 ms |
| `_refresh_storage_membership()`, per call | 0.71 ms | 1.06 ms | 0.98 ms |
| `_weather_storage()`, per call | 8.18 ms | 13.97 ms | 3.90 ms |

Each column is a four-second instrumented observation. The near-fire case ended after 4.44 wall seconds because the final frame ran long. The eight-second repeat returned four dense rebuilds at 28.4 ms each and three near-pile rebuilds at 641 ms each. Uninstrumented headless Chapter II sustained **23.5 sim s/s** for the 60/9 coal bed, **9.31** for the dense flame, **8.64** for 100/9 scorching and **1.71** for the near pile. In that last run, a Chapter II step alone reached **854 ms**. The headless fixture samples up to 160 steps and therefore reaches different fire ages from the rendered runs. It provides a solver throughput and spike check with zero scene rendering.

The network enumerates `N(N−1)/2` pairs on rebuild. The jump from 89 to 243 nodes produces **7.5×** as many candidates, **12.8×** as many accepted links, and about **24×** the build time in the short profile. Visibility tests search for occluders, so a denser active cluster increases work per accepted candidate as well as increasing the candidate count. An exact growth exponent for this stage would require more near-pile sizes. Active exchange costs rise roughly with accepted link count. Coal, fuel wear, movement, and storage membership can all dirty the network. In the undisturbed headless coal cases only one build ran in roughly 120–160 steps, which explains the relatively smooth cold-pile sweep.

| Mean headless `Fire.step()`, ms, calm coal bed | 0 drying | 3 drying | 6 drying | 9 drying |
| --- | ---: | ---: | ---: | ---: |
| No stock | 0.28 | 1.65 | 3.83 | 5.83 |
| 60 remote stored | 2.42 | 4.26 | 5.90 | 7.65 |
| 100 remote stored | 3.86 | 5.89 | 7.48 | 10.22 |

The remote-pile cost grows roughly linearly in the fixture. A storage update runs once per simulated second, about every four fixed steps. It samples local shelter conditions, exchanges heat and water on each exposed region, diffuses moisture, and synchronizes sections. At 60 and 100 pieces that work contributes about 2.0 and 3.5 ms per step amortized, with a periodic 8–14 ms burst. The shelf-neighbor loop can scan the stored population for each eligible piece and exits as soon as it finds cover. In the packed 60-piece shelf control, storage weather averaged 8.49 ms versus 8.18 ms in the dense off-shelf control. Spread-out shelf arrangements could cost more.

`_near_hot_fuel()` checks warm active wood and coals against a size-based reach. The membership scope is the measured inclusive cost of those checks and classification. In the ordinary Chapter II layout the scan adds less than about 1.1 ms per call and retains all 60 or 100 pieces in storage. Near the flame it promotes 30 pieces and changes the scale of downstream cost. Any change to promotion needs to verify heating and ignition at the boundary.

## Support, movement and responsiveness

`_settle()` orders active and stored fuel and calls `Structure.seat()` against the growing set of lower pieces. This searches for support contacts and recalculates height, loading, and stability. The full settle invalidates the thermal network, including when the log that moved remains in the remote pile. A quiet cold coal-bed pile settles rarely. A live dense flame gives three full passes in four seconds even with no input, **73 seat calls per pass**. Moving one log produced 26 passes and 1,898 seat calls in four seconds. Repeated placement produced 37 passes and 2,701 seat calls. A pass in that dense 60-piece fixture took **36–38 ms**, with `Structure.seat()` accounting for most of the time. The subsequent weight pass averaged about 0.6–0.8 ms across the measured cases. Search work can grow quadratically with pile size when each piece checks a growing list of possible contacts. The difference between equally sized loose and dense piles shows that contact layout strongly affects the cost.

| Normal-speed input path | Direct action P95 ms | Whole-frame P99 ms | FPS |
| --- | ---: | ---: | ---: |
| 60 dense, hit test and drag preview | 1.89 | 74.11 | 63.0 |
| 60 dense, turn | 0.02 | 70.79 | 69.5 |
| 60 dense, move one cold log | 41.33 | 64.96 | 41.8 |
| 60 dense, place between pile and hearth | 40.24 | 130.48 | 35.0 |
| 100 loose, move one cold log | 44.60 | 104.07 | 35.2 |
| 100 dense, move one cold log | 132.15 | 350.60 | 7.6 |

Move and place use the production pose operation, with moves attempted about every 140 ms. Picking a piece for preview exercises the game’s hit lookup and placement preview. Turning records the immediate call, with any subsequent simulation work counted in the whole-frame column. These are scripted action and frame measurements. A mouse-event-to-display latency trace and a separate timing of the rolling branch were outside this capture. The 100-piece dense move case also fell to **0.58 sim s/s** and repeated at the smaller resolution with **341 ms P99**. A quieter view or less GPU work alone cannot recover that interaction.

## Renderer, painted build, and family controls

| Same 60/9 dense flame layout, 1920×1016 window | FPS | P95 ms | P99 ms | Worst ms | Sim s/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Current, normal rendered | 64.3 | 24.87 | 82.41 | 100.95 | 0.98 |
| Simulation paused, stationary camera | 78.1 | 18.55 | 20.21 | 22.10 | 0.00 |
| Simulation paused, orbiting | 69.3 | 20.24 | 22.20 | 60.75 | 0.00 |
| Live, looking at the pile | 59.9 | 24.51 | 73.00 | 83.43 | 0.99 |
| Live, 3D viewport frozen and workbench render process disabled | 126.3 | 13.28 | 46.04 | 69.65 | 0.92 |
| Earlier, before the painted-world changes | 67.8 | 23.15 | 70.81 | 80.81 | 0.99 |
| Current, instrumented repeat at standard refresh | 56.6 | 34.36 | 81.36 | 99.60 | 0.99 |
| Current, instrumented repeat at reduced refresh and raster | 73.9 | 22.42 | 49.91 | 86.73 | 1.00 |
| Current, 1152×738 window, normal rendered | 67.9 | 23.25 | 54.96 | 83.61 | 1.00 |

The earlier build still hit ~71 ms P99 at 1× and advanced at 6.58 sim s/s with 16× selected. The current build advances at 6.66 sim s/s in that accelerated control. Both commits have the same `sim/fire.gd`. The comparison also spans changes outside rendering, so a specific increase cannot be assigned to a shader alone. The per-viewport GPU median for the matching short 1× flame controls was about 2.7 ms before and 3.4 ms after. Lowering the window in the coal sweep reduced the 100/9 P99 from 41 to 32 ms. The near-pile control remained at approximately 666–726 ms worst at either resolution, and the headless test reproduced the thermal stall. The render cost matters to normal frame pacing while the largest stalls are CPU-side.

The conservative render change in the eight-second repeat reduced the cost of `_ambient_effects()` from 1.33 to 0.20 ms per call and `_refresh()` from 4.32 to 3.07 ms per call. `Fire.step()` stayed around 21–22 ms. The frozen-viewport repeat likewise reduced frame time while leaving `Fire.step()` near 21 ms with a worst frame of 79 ms. Its saved GPU timestamp is stale once rendering stops. The render-off control leaves the root UI active.

In the short profile, `_refresh()` averaged 3.81 ms per call for dense 60/9 flame and 7.13 ms for 100/9 scorching, with a 16 ms maximum in the latter. The script scans fuel and updates visible state; the profiled log update averaged about 0.07 ms per call. `_shape_log_section()` caches a quantized wear fingerprint. Across each four-second capture it generated only 14–16 replacement `_wood_mesh()` calls, at ~0.46 ms each. No `_create_log()` calls appeared after warm-up in these cases. The painted materials are initialized and reused by the persistent log nodes, with state updated by parameters. The update path also writes collision pose when it updates a piece, but no separate collision-write spike was measured. Stored pieces can avoid log updates when their fingerprints and poses agree, yet the renderer still scans them and pose churn can defeat that guard.

Looking at the dense pile raised median draw submissions from about 1,107 to 1,949 and measured render CPU time from about 1.0 to 2.8 ms. Paused orbit was the only paused case with a frame over 33 ms in this capture. Facing away reduces render submissions. The script still scans the piece list. In the eight-second family control, one active workshop job changed P99 from about 57 to 58 ms, and `show_workshop()` averaged 0.08 ms per frame. This measures a job versus the same family present and idle.

| Median Godot counters by rendered scene | Objects | Scene nodes | Log mesh nodes | Tracked static RAM |
| --- | ---: | ---: | ---: | ---: |
| Empty coal bed | 3,726 | 758 | 0 | 65.1 MiB |
| 60/9 coal bed | 6,199 | 1,072 | 176 | 78.8 MiB |
| 100/9 coal bed | 7,470 | 1,251 | 275 | 86.4 MiB |
| 60/9 dense flame | 6,872 | 1,148 | 186 | 81.3 MiB |
| 100/9 scorching | 8,324 | 1,376 | 285 | 89.1 MiB |
| 60/9 near fire | 13,028 | 1,156 | 186 | 90.8 MiB |

The engine reported roughly 110–118 MiB of tracked video allocations in these cases. The source of allocation or driver pauses remains unverified. The setup emitted intermittent GLES material warnings and a root-certificate warning in baseline runs. Short runs make P99 sensitive to a few frames. The eight-second repeat confirmed the dense-settle and near-network tails, with some GPU variation across observations. The scorch fixture starts some logs warm to make the condition reproducible over a short capture.

Two uninstrumented 30-second runs at 1920×1016 measured 89 ms P99 with 100/9 scorching and 78 ms P99 with 60/9 dense flame. They produced 83 and 68 frames over 33.3 ms, respectively, while both maintained 1.00 sim s/s. The worst frames were 132 and 111 ms. Windows process samples collected roughly twice a second across both runs gave a median working set of 297 MiB (peak 315 MiB) and median private memory of 522 MiB (peak 559 MiB), trimming startup and exit. The raw samples are in [Windows process memory](outputs/performance-3.3.1/process-memory.json). These runs establish recurring frame stalls under sustained load. A long-session memory-growth test remains separate.

### Godot’s script and GPU profilers

Godot’s command-line profiler sampled the dense 60/9 move replay at 1920×1016. In a 117 ms move frame, script took 90 ms. The pose call accounted for 76 ms, including 75 ms of settling and 68 ms across 73 seat calls. In a following 97 ms frame, `Fire.step()` accounted for 60 ms, including a 42 ms network rebuild and 12 ms in radiation visibility. GDScript profiling increased the workload, so these traces confirm attribution and call counts. Use the uninstrumented sweeps for frame rates and the scoped runs for comparable per-call averages.

The script profiler also showed that the dummy driver still ran the fire-audio generator. In an uninstrumented eight-second steady flame comparison, disabling its process in the fixture moved mean frame time from 14.73 to 14.09 ms and P99 from 51.19 to 50.72 ms. Audio synthesis adds some CPU work with this driver. The same tail persisted with it disabled.

The GPU section names shadows, depth prepass, opaque, transparent and canvas passes. Its Compatibility console output showed large swings and occasional viewport-end timestamps greater than the printed total. Pass timings are therefore unsuitable for assigning a shader-specific stall. Viewport timers, reduced raster, paused orbit, and headless timings provide the CPU/GPU comparison used above. [Raw Godot profiler trace](outputs/performance-3.3.1/godot-profiler.log)

The existing thermal suite passed 31 checks. The existing woodpile suite passed 20 and failed five, with the same five failures reproduced on a clean archive of the baseline. Those checks cover opening stock, collection counts and placement of stocked wood. This benchmark starts from the real Chapter II practice setup and seeds its own stock to hold the comparison constant. [Baseline woodpile suite](outputs/performance-3.3.1/checks-verification-woodpile.log)

## Fixes in priority order

| Rank | Target | Expected impact | Complexity and regression risk |
| --- | --- | --- | --- |
| 1 | Recalculate support and weight only around the changed piece and its support dependents. Keep remote pose changes out of thermal invalidation where they cannot affect the active hearth or its occlusion. | Highest immediate improvement to picking up and moving stock. Current dense move spends roughly 36–42 ms per full 60-piece settle and reaches 132 ms at the 100-piece action tail. | Medium to high. Preserve traversal order, settling, rolling, stacking, active contact, and the loading chain. Replay bridge and stack failures as well as ordinary placement. |
| 2 | Use a conservative spatial broad phase for thermal candidates and visibility occluders. Cache geometry-dependent results, with separate invalidation for topology and evolving thermal coefficients. | Highest improvement near the hearth when stock becomes active. Dense placement currently pushes builds to nearly every step. A promoted cluster takes about 0.6 s to rebuild. | High. Preserve pair order and each current reach rule. Coal size and char, shielding, and ember and plume feedback need correct invalidation. Compare exact candidates and visibility first, then drying and propagation over time. |
| 3 | Cache local shelf spacing and environmental queries, and spread periodic storage work if the integrated results match. | Reduces the 8–14 ms weather burst and steady cost of remote wood. A subset of returned-state checks also applies to membership. | Medium. Keep segmented water and heat, rain and seep exposure, drying-rate differences, and correct promotion. Verify elapsed-time integration against the current model at 1× and accelerated speed. |
| 4 | Track changed pose and appearance independently, skip stationary collision updates, and defer work that an off-camera piece does not need immediately. Revisit batching and effect reuse after profiling the dirty updates. | Improves frame headroom in the normal rendered scene. Most warm work is per-piece updates and effects. Cached mesh creation is already infrequent. | Medium. Keep placement hit tests and steam, wetness, char, glow and ash feedback accurate when a log comes into view or is picked up. |
| 5 | Re-evaluate the step scheduler and display achieved acceleration once the costs above fall. | Makes high speeds more predictable. A single expensive synchronous step currently defeats an 8.5 ms budget. | Medium. Keep fixed-step physics and avoid a backlog that creates a burst when the player returns to 1×. |

## Acceptance targets on this GTX 1070 Ti PC

- At **1×**, with 100 stored pieces and nine drying logs, aim for at least 60 FPS, P95 ≤20 ms, P99 ≤33 ms, and zero frames over 50 ms in steady one-minute flame and scorching runs. Require 0.98–1.02 simulated seconds per wall second after warm-up. Validate both pile shapes and camera directions.
- While moving wood, aim for ≤4 ms P95 for preview, ≤8 ms for a remote move, and ≤12 ms for placing a piece. Require ≤33 ms P99 whole-frame time in the same manipulation fixture. Use the near-fire promotion case as a separate regression test with an interim worst-frame target under 100 ms.
- At **16×**, target ≥14 simulated seconds per second (56 steps/s) at ≥30 FPS with P95 ≤40 ms in the dense flame case. At **64×**, initially target 24–32 simulated seconds per second (96–128 steps/s) at ≥30 FPS, with achieved speed shown to the player if it falls short. A true 64× would require 256 fixed steps/s or less than 3.91 ms of model time per step even if rendering were free. The current empty scene reaches only 36× in the uncapped rendered run.

The measured reductions under the reduced-render control support the 1× average-FPS target. Reaching the frame-tail targets still requires fixing the measured support and thermal bursts. The accelerated targets are acceptance goals for later benchmarking, with the dense-flame controls at roughly 6.6 sim s/s today.

## Full benchmark matrix

### 1920×1016

#### 1× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.38 | 7.68 | 13.96 | 16.24 | 18.45 | 119.29 | 1.00 | 3.99 |
| 0 | 3 | 8.99 | 8.24 | 14.85 | 16.36 | 18.08 | 111.27 | 1.00 | 3.99 |
| 0 | 6 | 9.45 | 8.66 | 15.01 | 17.56 | 19.61 | 105.81 | 0.99 | 3.98 |
| 0 | 9 | 11.17 | 10.08 | 18.36 | 21.57 | 25.36 | 89.54 | 1.00 | 4.00 |
| 20 | 0 | 9.01 | 8.27 | 14.52 | 16.75 | 18.65 | 110.95 | 1.00 | 3.99 |
| 20 | 3 | 9.72 | 8.95 | 15.44 | 16.46 | 17.41 | 102.91 | 1.00 | 3.99 |
| 20 | 6 | 10.49 | 9.52 | 16.69 | 17.95 | 23.89 | 95.34 | 1.00 | 3.99 |
| 20 | 9 | 11.03 | 9.88 | 17.57 | 20.45 | 24.35 | 90.67 | 1.00 | 3.99 |
| 40 | 0 | 9.28 | 8.45 | 14.93 | 17.24 | 21.87 | 107.75 | 1.00 | 3.99 |
| 40 | 3 | 9.88 | 9.03 | 15.55 | 17.42 | 19.89 | 101.26 | 1.00 | 3.99 |
| 40 | 6 | 10.57 | 9.55 | 16.35 | 19.65 | 20.14 | 94.60 | 1.00 | 3.99 |
| 40 | 9 | 11.04 | 10.06 | 16.91 | 21.92 | 22.94 | 90.62 | 0.90 | 3.59 |
| 60 | 0 | 9.86 | 9.07 | 15.70 | 18.64 | 19.69 | 101.46 | 0.90 | 3.60 |
| 60 | 3 | 10.57 | 9.52 | 16.40 | 20.95 | 29.86 | 94.63 | 1.00 | 3.99 |
| 60 | 6 | 11.40 | 10.34 | 16.93 | 23.25 | 31.50 | 87.71 | 1.00 | 3.99 |
| 60 | 9 | 11.95 | 10.78 | 18.05 | 25.12 | 28.48 | 83.71 | 1.00 | 3.99 |
| 100 | 0 | 11.55 | 10.53 | 16.97 | 26.78 | 33.22 | 86.59 | 1.00 | 3.99 |
| 100 | 3 | 12.96 | 11.52 | 19.99 | 36.54 | 42.94 | 77.17 | 0.90 | 3.60 |
| 100 | 6 | 13.25 | 12.03 | 19.21 | 32.41 | 39.15 | 75.45 | 1.00 | 3.99 |
| 100 | 9 | 13.57 | 12.25 | 19.62 | 41.12 | 41.59 | 73.70 | 1.00 | 3.98 |

#### 16× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 8.31 | 7.72 | 13.87 | 15.03 | 16.00 | 120.34 | 15.99 | 63.97 |
| 0 | 3 | 11.66 | 10.84 | 18.15 | 21.42 | 22.98 | 85.80 | 15.96 | 63.85 |
| 0 | 6 | 12.55 | 12.00 | 18.92 | 22.12 | 25.30 | 79.69 | 15.84 | 63.35 |
| 0 | 9 | 23.11 | 23.34 | 34.25 | 37.59 | 53.82 | 43.26 | 15.98 | 63.90 |
| 20 | 0 | 13.19 | 10.82 | 20.37 | 25.11 | 53.25 | 75.84 | 15.97 | 63.87 |
| 20 | 3 | 12.53 | 11.40 | 18.89 | 21.94 | 42.74 | 79.84 | 15.87 | 63.47 |
| 20 | 6 | 14.08 | 13.02 | 21.14 | 25.78 | 57.26 | 71.00 | 15.97 | 63.86 |
| 20 | 9 | 24.18 | 20.85 | 34.66 | 61.59 | 118.36 | 41.36 | 16.01 | 64.03 |
| 40 | 0 | 11.57 | 10.03 | 16.45 | 21.86 | 47.51 | 86.41 | 16.03 | 64.11 |
| 40 | 3 | 13.92 | 11.82 | 23.67 | 28.43 | 41.12 | 71.84 | 15.87 | 63.46 |
| 40 | 6 | 19.67 | 18.95 | 30.33 | 37.51 | 42.15 | 50.85 | 15.99 | 63.96 |
| 40 | 9 | 31.14 | 29.51 | 46.08 | 47.45 | 47.45 | 32.11 | 14.37 | 57.48 |
| 60 | 0 | 13.79 | 10.93 | 25.46 | 32.52 | 32.98 | 72.52 | 15.94 | 63.75 |
| 60 | 3 | 22.02 | 18.79 | 37.05 | 40.09 | 46.24 | 45.41 | 15.93 | 63.74 |
| 60 | 6 | 31.83 | 33.01 | 45.50 | 57.19 | 57.19 | 31.42 | 15.21 | 60.85 |
| 60 | 9 | 38.68 | 39.43 | 50.58 | 64.17 | 64.17 | 25.85 | 12.63 | 50.51 |
| 100 | 0 | 21.99 | 15.25 | 41.28 | 43.37 | 48.85 | 45.47 | 15.95 | 63.82 |
| 100 | 3 | 33.88 | 33.68 | 47.82 | 87.71 | 87.71 | 29.52 | 15.26 | 61.03 |
| 100 | 6 | 32.45 | 31.64 | 48.44 | 66.96 | 66.96 | 30.81 | 15.11 | 60.44 |
| 100 | 9 | 36.00 | 30.95 | 53.86 | 77.36 | 77.36 | 27.78 | 10.52 | 42.07 |

#### 64× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 12.64 | 10.86 | 19.87 | 31.35 | 34.11 | 79.11 | 36.26 | 145.03 |
| 0 | 3 | 18.57 | 19.90 | 28.30 | 49.59 | 80.83 | 53.84 | 36.39 | 145.56 |
| 0 | 6 | 21.03 | 19.25 | 30.67 | 31.73 | 32.87 | 47.56 | 33.67 | 134.68 |
| 0 | 9 | 24.10 | 22.71 | 32.94 | 37.42 | 38.23 | 41.50 | 20.65 | 82.59 |
| 20 | 0 | 9.47 | 7.63 | 15.64 | 20.47 | 22.73 | 105.54 | 36.28 | 145.12 |
| 20 | 3 | 15.17 | 18.53 | 26.53 | 30.11 | 31.39 | 65.90 | 36.44 | 145.78 |
| 20 | 6 | 20.39 | 19.68 | 26.85 | 28.55 | 29.51 | 49.05 | 32.00 | 128.00 |
| 20 | 9 | 23.20 | 22.47 | 31.40 | 34.67 | 35.77 | 43.09 | 21.25 | 84.99 |
| 40 | 0 | 11.69 | 7.63 | 23.81 | 29.36 | 32.87 | 85.51 | 36.26 | 145.05 |
| 40 | 3 | 20.04 | 22.40 | 29.03 | 29.68 | 34.89 | 49.91 | 36.43 | 145.74 |
| 40 | 6 | 20.09 | 19.18 | 25.76 | 26.78 | 40.17 | 49.78 | 24.79 | 99.16 |
| 40 | 9 | 26.33 | 26.93 | 34.99 | 43.57 | 43.57 | 37.98 | 18.69 | 74.77 |
| 60 | 0 | 15.10 | 19.15 | 25.63 | 26.53 | 27.27 | 66.23 | 36.21 | 144.84 |
| 60 | 3 | 28.49 | 26.72 | 33.66 | 37.83 | 37.83 | 35.10 | 34.40 | 137.61 |
| 60 | 6 | 22.93 | 21.47 | 28.30 | 32.85 | 45.12 | 43.61 | 21.80 | 87.21 |
| 60 | 9 | 29.39 | 30.27 | 40.34 | 48.82 | 48.82 | 34.02 | 16.71 | 66.85 |
| 100 | 0 | 29.27 | 27.76 | 34.87 | 36.72 | 36.72 | 34.17 | 33.87 | 135.48 |
| 100 | 3 | 36.36 | 34.99 | 42.02 | 65.56 | 65.56 | 27.50 | 26.01 | 104.04 |
| 100 | 6 | 27.97 | 28.49 | 37.80 | 70.00 | 70.00 | 35.76 | 17.88 | 71.51 |
| 100 | 9 | 33.50 | 36.20 | 47.21 | 71.08 | 71.08 | 29.85 | 14.63 | 58.52 |

### 1152×738

#### 1× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 7.43 | 6.91 | 13.04 | 13.36 | 14.49 | 134.56 | 1.00 | 3.99 |
| 0 | 3 | 8.89 | 7.86 | 14.12 | 18.73 | 19.40 | 112.51 | 1.00 | 3.99 |
| 0 | 6 | 8.81 | 8.15 | 14.11 | 15.85 | 18.92 | 113.53 | 0.90 | 3.60 |
| 0 | 9 | 9.19 | 8.36 | 14.71 | 19.76 | 20.89 | 108.76 | 0.99 | 3.97 |
| 20 | 0 | 8.35 | 7.57 | 13.79 | 15.67 | 17.50 | 119.82 | 1.00 | 3.99 |
| 20 | 3 | 8.63 | 7.96 | 14.03 | 14.62 | 17.34 | 115.87 | 1.00 | 4.00 |
| 20 | 6 | 9.35 | 8.55 | 14.65 | 16.18 | 19.57 | 106.90 | 0.99 | 3.97 |
| 20 | 9 | 10.10 | 8.96 | 15.34 | 20.87 | 30.27 | 99.03 | 0.99 | 3.98 |
| 40 | 0 | 8.62 | 7.95 | 14.12 | 15.56 | 20.72 | 115.98 | 1.00 | 3.99 |
| 40 | 3 | 9.61 | 8.63 | 14.98 | 17.19 | 25.28 | 104.08 | 1.00 | 3.99 |
| 40 | 6 | 9.87 | 9.00 | 15.13 | 18.97 | 24.63 | 101.28 | 1.00 | 3.99 |
| 40 | 9 | 10.45 | 9.34 | 15.97 | 21.38 | 28.02 | 95.73 | 1.00 | 3.99 |
| 60 | 0 | 9.21 | 8.50 | 14.81 | 18.14 | 19.17 | 108.54 | 1.00 | 3.99 |
| 60 | 3 | 10.01 | 9.18 | 15.55 | 20.50 | 26.80 | 99.86 | 1.00 | 3.99 |
| 60 | 6 | 10.38 | 9.38 | 15.78 | 22.84 | 29.81 | 96.37 | 1.00 | 4.00 |
| 60 | 9 | 10.86 | 9.78 | 16.23 | 24.81 | 31.56 | 92.07 | 1.00 | 3.99 |
| 100 | 0 | 10.94 | 9.79 | 16.07 | 25.23 | 31.23 | 91.44 | 1.00 | 3.99 |
| 100 | 3 | 10.93 | 9.82 | 16.24 | 27.57 | 32.99 | 91.52 | 1.00 | 4.00 |
| 100 | 6 | 11.63 | 10.28 | 16.94 | 29.08 | 40.67 | 85.99 | 1.00 | 4.00 |
| 100 | 9 | 12.19 | 10.77 | 17.59 | 32.28 | 39.29 | 82.02 | 1.00 | 3.98 |

#### 16× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 7.45 | 6.97 | 12.80 | 13.69 | 14.33 | 134.29 | 15.89 | 63.55 |
| 0 | 3 | 9.03 | 8.77 | 14.76 | 15.68 | 18.61 | 110.77 | 15.94 | 63.75 |
| 0 | 6 | 10.63 | 10.76 | 17.02 | 17.91 | 18.02 | 94.10 | 15.95 | 63.80 |
| 0 | 9 | 15.30 | 14.17 | 21.12 | 30.60 | 33.97 | 65.34 | 15.94 | 63.75 |
| 20 | 0 | 8.57 | 7.72 | 13.91 | 16.77 | 18.04 | 116.74 | 16.04 | 64.15 |
| 20 | 3 | 10.83 | 9.97 | 17.53 | 20.90 | 23.16 | 92.30 | 15.98 | 63.93 |
| 20 | 6 | 12.65 | 11.58 | 19.45 | 23.77 | 25.18 | 79.08 | 15.97 | 63.90 |
| 20 | 9 | 15.95 | 14.41 | 22.45 | 23.81 | 31.08 | 62.69 | 15.97 | 63.89 |
| 40 | 0 | 9.40 | 8.09 | 14.72 | 20.09 | 20.87 | 106.35 | 15.99 | 63.97 |
| 40 | 3 | 11.54 | 10.20 | 16.77 | 21.97 | 30.98 | 86.63 | 15.97 | 63.88 |
| 40 | 6 | 14.34 | 12.39 | 20.48 | 25.34 | 27.34 | 69.75 | 15.94 | 63.77 |
| 40 | 9 | 19.07 | 19.43 | 27.87 | 29.55 | 32.62 | 52.44 | 15.89 | 63.57 |
| 60 | 0 | 10.54 | 8.51 | 18.12 | 23.23 | 24.40 | 94.88 | 15.95 | 63.78 |
| 60 | 3 | 14.18 | 11.50 | 25.40 | 36.74 | 40.32 | 70.51 | 15.83 | 63.34 |
| 60 | 6 | 16.75 | 13.07 | 28.62 | 29.71 | 47.72 | 59.71 | 15.92 | 63.70 |
| 60 | 9 | 26.91 | 26.51 | 40.73 | 50.69 | 50.69 | 37.16 | 15.98 | 63.92 |
| 100 | 0 | 13.83 | 10.09 | 29.92 | 31.53 | 32.95 | 72.29 | 15.97 | 63.90 |
| 100 | 3 | 18.01 | 13.15 | 33.72 | 36.07 | 54.91 | 55.54 | 15.98 | 63.93 |
| 100 | 6 | 26.38 | 23.27 | 42.56 | 63.21 | 63.21 | 37.91 | 15.86 | 63.45 |
| 100 | 9 | 32.72 | 29.36 | 45.64 | 67.46 | 67.46 | 30.56 | 14.59 | 58.35 |

#### 64× requested

| Stored | Drying | Mean ms | Median ms | P95 ms | P99 ms | Max ms | FPS | Sim s/s | Steps/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 7.68 | 7.35 | 10.67 | 14.49 | 29.68 | 130.26 | 36.26 | 145.05 |
| 0 | 3 | 11.94 | 7.93 | 24.12 | 27.93 | 36.02 | 83.77 | 36.40 | 145.60 |
| 0 | 6 | 20.26 | 19.33 | 27.33 | 29.23 | 29.90 | 49.35 | 36.22 | 144.87 |
| 0 | 9 | 20.44 | 19.04 | 27.06 | 33.61 | 34.86 | 48.93 | 24.27 | 97.06 |
| 20 | 0 | 10.36 | 8.29 | 18.11 | 23.42 | 36.40 | 96.51 | 36.19 | 144.76 |
| 20 | 3 | 25.33 | 24.92 | 35.41 | 36.60 | 36.60 | 39.47 | 33.59 | 134.37 |
| 20 | 6 | 22.90 | 21.99 | 30.34 | 33.21 | 34.66 | 43.66 | 26.59 | 106.38 |
| 20 | 9 | 24.45 | 23.60 | 31.38 | 35.37 | 37.23 | 40.90 | 20.15 | 80.61 |
| 40 | 0 | 12.82 | 8.23 | 26.71 | 30.65 | 31.28 | 77.99 | 36.30 | 145.19 |
| 40 | 3 | 24.78 | 23.70 | 32.32 | 40.75 | 41.57 | 40.36 | 36.46 | 145.84 |
| 40 | 6 | 20.71 | 19.60 | 26.59 | 29.24 | 34.75 | 48.30 | 24.05 | 96.20 |
| 40 | 9 | 26.04 | 26.53 | 35.89 | 40.89 | 40.89 | 38.40 | 18.90 | 75.60 |
| 60 | 0 | 17.51 | 20.47 | 29.28 | 31.38 | 31.86 | 57.12 | 36.25 | 145.00 |
| 60 | 3 | 29.24 | 27.73 | 34.31 | 39.80 | 39.80 | 34.20 | 33.50 | 134.01 |
| 60 | 6 | 23.73 | 22.89 | 28.56 | 37.58 | 53.12 | 42.14 | 21.07 | 84.28 |
| 60 | 9 | 28.55 | 30.07 | 38.81 | 46.18 | 46.18 | 35.02 | 17.21 | 68.85 |
| 100 | 0 | 29.81 | 28.07 | 35.09 | 40.90 | 40.90 | 33.55 | 33.25 | 132.99 |
| 100 | 3 | 37.00 | 36.17 | 43.72 | 72.91 | 72.91 | 27.03 | 24.74 | 98.96 |
| 100 | 6 | 30.37 | 29.34 | 44.77 | 74.35 | 74.35 | 32.93 | 16.36 | 65.45 |
| 100 | 9 | 34.26 | 32.30 | 48.16 | 66.95 | 66.95 | 29.19 | 13.90 | 55.59 |
