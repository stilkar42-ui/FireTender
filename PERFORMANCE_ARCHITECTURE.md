# Firetender Phase 3.4 performance architecture

Phase 3.4 starts from local `codex/phase-3.3.2-performance` at `9b7c69d`. The comparison uses Godot 4.7.2, Windows 10, an i5-7500 and a GTX 1070 Ti. The source benchmark uses the Compatibility renderer at 1920×1016 with VSync disabled and dummy audio. Results apply to these fixtures, machine and sample durations.

## Architecture

- **Ordered thermal exchange.** Fire keeps ownership of every piece and regional state. On a topology rebuild, it prepares a compact stream of links in the existing solver order. Each fixed step packs only live thermal inputs. The Windows extension evaluates conduction, ember and flame feedback, and radiation in one traversal, then returns the per-node accumulators. Fibre packing and bed shelter still precede environmental heat loss. Accumulation follows the same index order and uses binary64, with binary32 dot products where the original Godot Vector2 uses them. Small networks and unsupported runtimes use the GDScript path.
- **Spatial queries and topology.** The extension runs the conservative sweep for larger active graphs. Script applies the original reach, solid contact, shielding, air passage, plume and normalization equations. The occlusion grid also serves air passage checks, while an ordered spatial index excludes distant stock from background wind queries. Topology is rebuilt on the existing material and structural invalidations. This preserves the original schedule, including when mass-dependent coefficients are sampled.
- **Structure.** Phase 3.3.2's cached stable fits remain in use. For dense stacks the extension computes candidate floor heights and scores available slopes using contiguous buffers. It preserves the support iteration order, clearances and first-wins ties. Godot applies the selected contacts and carries the loads, breakage, gravity and rolling forward.
- **Activity and weather.** Cold storage retains the existing one-simulated-second ambient/weather pass, with shared shelter samples for the two faces when they share plan coordinates. All regional moisture and enthalpy updates still run. The existing hearth, temperature and spark-contact rules promote pieces to the full solver with their existing contents. Active temperature and moisture diffusion, charring, volatile release, gas ignition, charcoal, ash, residue, airflow and workshop heat stay under the game model's fixed quarter-second steps.
- **Rendering.** Stored-piece visuals reuse the captured pose, roll angle and moisture sample until storage weather or movement updates them. Painted wind strokes are redrawn at up to 30 Hz. Airflow, temperature, smoke and fuel in the simulation remain independent of the drawing cadence.

### Why a small native extension

A narrow Godot C ABI bridge passes packed arrays in batches. It uses the API header dumped by the runtime and the script scene's usual methods. Setup, reactions, interior diffusion, story, interaction, audio and the painted world stay in Godot. At each sample the solver needs one ordered accumulation per edge into shared destinations. Parallel writes would need serialized accumulation or a deterministic reduction and extra buffers. The prototype profiled the serial kernel first. No worker threads were enabled on this four-core machine.

## Isolated prototype

The exchange prototype ran in an empty Godot project before the kernel was wired into the game. All inputs were seeded and identical between the packed GDScript reference and extension. Timings include engine call and return. The boundary control passes identical buffers and returns an allocated buffer without running the exchange. Payload is the size of the input and result array elements.

| Nodes | Links | GDScript exchange | Native exchange | Boundary control | Array payload |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 89 | 595 | 0.964 ms | 0.0109 ms | 0.00061 ms | 82 KiB |
| 243 | 6,825 | 14.885 ms | 0.141 ms | 0.00080 ms | 832 KiB |
| 480 | 13,935 | 25.242 ms | 0.236 ms | 0.00177 ms | 1,697 KiB |

All output elements matched exactly and repeated executions returned the same values. The largest absolute sum of signed conductive flux was 1.91 × 10⁻¹² kW. The prototype performs one output packed-array allocation per call and uses borrowed, read-only packed-array storage for inputs. The table excludes Godot process overhead and allocator metadata. The full matrix records sampled Godot static memory and object counts. Process-wide allocation event counts are unavailable.

## Physics and saves

The regional thermal trace samples both faces, the core and interior lanes once per simulated second over 160 fixed steps per fixture. It includes temperatures, water, fuel, char, ash, gas, heat capacity, internal heat, signed conduction, plume and radiation, plus the network's coefficients. Phase 3.3.2, native Phase 3.4 and Phase 3.4 with `--reference-fire` match at full JSON floating-point precision in the calm coal, dense flame, scorch, near-pile promotion and cold cabin ignition fixtures. The cold cabin first reaches 0.20 kW of flame at 4.5 seconds in all three runs. The 210 support snapshots cover top and middle moves, removal of the bottom support, rotation and induced collapse.

Save format version 4 retains the existing piece, pose, material and link data. Spatial and packed buffers are derived after loading. The fallback path is available on all platforms and selected explicitly by adding `-- --reference-fire` to a game launch. Windows logs a diagnostic if the native component is unavailable or its interface is stale.

## Reproducing the captures and build

From PowerShell at the repository root, use the console build of standard-precision Godot 4.7.2, Python 3 and portable Zig 0.15.2. The Windows x86-64 Zig package used here has SHA-256 `3a0ed1e8799a2f8ce2a6e6290a9ff22e6906f8227865911fb7ddedc3cc14cb0c`. The GDExtension uses Godot's documented C interface. [Godot GDExtension documentation](https://docs.godotengine.org/en/stable/engine_details/engine_api/gdextension/index.html)

```powershell
& .\native\build.ps1 -Godot $godot -Zig $zig
& .\tools\run_phase_34_benchmark.ps1 -Godot $godot -Destination outputs/performance-3.4-repeat
& .\tools\export_phase_34.ps1 -Godot $godot -WindowsTemplate $windowsReleaseTemplate
```

Use the official Windows x86-64 release template from the same Godot release. The playtest folder includes the executable, adjacent PCK and native DLL. The DLL and executable use the Windows system runtime. The EXE uses the existing Firetender profile location in Windows. [Godot project data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

The 120-case grid crosses 20, 60, 100 and 150 stored pieces with 3, 6, 9 and 12 drying logs at 1×, 16× and 64× for coal and dense flame. A loose scorching fixture adds 9 and 12 drying logs at every stock count and speed. The rendered captures sample three wall seconds after setup. The corresponding headless matrix measures 24 identical fixed steps per row. Headless speed labels identify the paired rendered cases, since the headless loop measures unrestricted solver throughput. Separate action cases move a dense-stack log repeatedly, move a bottom support, trigger a large collapse, and bring a seeded cluster into thermal range. The action harness calls the same production placement operation as the player. Promotion timing comes from the seeded scene and scheduler.

## Chapter II results

The matched [rendered comparison](outputs/performance-3.4/benchmark-delivery/comparison-architecture.csv), [headless comparison](outputs/performance-3.4/benchmark-delivery/comparison-headless_architecture.csv) and [action comparison](outputs/performance-3.4/benchmark-delivery/comparison-architecture_actions.csv) report each fixture. These are medians across the 40 cases at each speed, with P99 computed separately in each run.

| Requested speed | Median FPS | Median P99 frame | Median actual sim speed |
| ---: | ---: | ---: | ---: |
| 1× | 46.8 → 75.2 | 64.2 → 39.0 ms | 0.99× → 0.99× |
| 16× | 27.9 → 25.6 | 64.3 → 74.6 ms | 7.71× → 7.72× |
| 64× | 25.3 → 27.2 | 78.1 → 62.7 ms | 6.66× → 9.42× |

At 1×, 31 of 40 cases reached 60 FPS, up from 8. With 100 stored pieces and nine scorching logs, FPS rose from 36.3 to 64.8 and P99 frame time fell from 75.6 to 45.5 ms. The 100-piece dense flame case reached 64.7 FPS. With 150 stored pieces and twelve drying logs, dense flame reached 44.2 FPS and loose scorching reached 27.3 FPS. Median sampled Godot static memory for the 1× matrix was 84.0 → 84.4 MiB.

| 1× rendered interaction | Direct P95 | Frame P99 |
| --- | ---: | ---: |
| Move a log repeatedly, 100-piece dense pile | 60.0 → 36.1 ms | 164.7 → 118.0 ms |
| Move a bottom support, 100-piece dense pile | 65.4 → 30.7 ms | 105.4 → 78.0 ms |
| Remove the root support, 100-piece collapse | 56.1 → 40.5 ms | 163.6 → 98.1 ms |
| Move a log repeatedly, 150-piece dense pile | 142.3 → 63.8 ms | 329.8 → 182.6 ms |
| Remove the root support, 150-piece collapse | 120.4 → 72.2 ms | 216.5 → 154.5 ms |
| Near-hearth workload with 43 active pieces | — | 403.2 → 393.9 ms |

The sequential headless rerun measured a median 15.1 → 19.8 simulated seconds per wall second across the 120 cases. Matched mean fixed-step time fell from 18.28 to 11.74 ms for 60/9 dense flame and from 20.02 to 14.85 ms for 100/9 scorch. The 150/12 scorch fixture averaged 67.44 → 59.33 ms per step.

In a separate placement test, moving one hot log near the pile raised the active population from 6 to 68. It produced 354 thermal nodes and 14,143 links. The largest rendered hitch was 791 → 746 ms. The matched 24-step headless replay improved from 162 to 97 ms per step on average and still hit 633 ms on its slowest rebuild. [Baseline placement capture](outputs/performance-3.4/benchmark-delivery/before-promotion.jsonl) · [Phase 3.4 placement capture](outputs/performance-3.4/benchmark-delivery/after-promotion.jsonl)

### Remaining bottlenecks

The native candidate pass lowered its mean in a spot profile from about 33 ms to 3 ms in the 243-node near-hearth graph. Those instrumented samples ran under different host load and establish the relative size of the scope. The expensive work now lies in the accepted graph: thousands of detailed air path, solid contact, view and coefficient checks per rebuild, followed by regional reactions and moisture/enthalpy exchange every tick. A cold stack is excluded from external heat exchange until its location and temperature require inclusion. Once most of that stack enters the hearth network, the physical neighborhood is genuinely dense and this version still rebuilds the accepted interactions together.

True 64× requires a quarter-second step every 3.91 ms on average including overhead. The frame scheduler has an 8.5 ms budget and can yield only between steps. Even the matched 60/9 dense-flame headless mean exceeds the per-step budget for 64×. Chunking topology work or incrementally updating individual links would need to preserve shielding and normalization inputs and the tick at which changed geometry becomes visible to the solver. This pass leaves these dependency boundaries in place.

## Regression checks

The 20 model suites passed, including 46 combustion checks and the two-hour deterministic replay. Seventeen rendered suites passed, including the full Chapter I–III journey, painted workbench, weather, save/load and the drying objectives. The painted-world capture script wrote all eleven camera views. The older version 4 Chapter II save restored and advanced. The packaged project loaded the 166-piece stress save with the native backend and advanced four fixed steps under the Windows Compatibility renderer.

Four pre-existing failures in the Red Hollow scene suite reproduced with the same assertions as Phase 3.3.2. Two concern opening woodpile and return-to-pile counts, and two concern the scout return and conversation. The suite reported 14 passes and four failures. Benchmark logs also contain existing Compatibility material warnings during scene disposal.

### Playtesting

Extract the [Windows playtest ZIP](outputs/performance-3.4/Firetender-Phase-3.4-Windows.zip) and launch Firetender.exe. The included Chapter II stress save can be copied to an empty profile slot using the package readme. To build the scenario yourself, start a new story and press **F7** at the hearth for Chapter II practice. Keep a strong coal bed and add dry twigs to start a flame. Place nine wet logs near the edge so that some faces steam or scorch. Stack gathered wood under cover, then move one piece at a time from the upper and lower courses. Use the speed buttons for 1×, 16× and 64× and watch both input response and the fire clock.
