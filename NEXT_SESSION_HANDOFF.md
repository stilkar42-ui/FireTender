# Firetender handoff · November 18, 2026

## Completed

- Phase 3.3.2 made individual stored logs persistent, improved support fitting and rendering updates, and separated cold storage from the active hearth.
- Phase 3.4 moved ordered exchange, candidate pruning and support fitting into the Windows extension, with indexed wind and shielding queries and a GDScript fallback.
- Phase 3.4.1 added batched native graph construction. Finalization restored Phase 3.4’s coefficient sampling boundaries after tracing extra residue-driven resampling. Settling still reuses a graph when active geometry and coefficient inputs match.

## Current architecture and verification

- `sim/fire.gd` owns physical state and the fixed 0.25 s step. The extension builds ordered links and evaluates exchange from packed buffers. GDScript handles combustion, moisture, wear, structure and story, and can build and solve the full graph with `--reference-fire`.
- Version 4 saves store physical state and the sampled topology in their original representation. New saves also record the sampled material signature. Older saves load with their saved links and refresh the signature at the next settle.
- All five thermal replays matched Phase 3.4 and both backends exactly. All 210 structural snapshots matched. Native/GDScript comparisons matched 33 graph fixtures and 12 active save/reload snapshots. The final headless mass-promotion step peaked at 46.3 ms versus 606 ms at baseline. A rendered spot check measured 83.4 FPS at 60/6 coals, 71.3 FPS at 100/9 dense flame and 51.5 FPS at 150/12 scorching. See [performance results](PERFORMANCE_ARCHITECTURE_3_4_1.md).

## Next session

- Trace the remaining 149–151 ms rendered promotion spike and sustained combustion cost with matched, correlated simulation, main-thread, render submission, GPU synchronization and frame pacing measurements. The ~19 ms graph rebuild accounts for only part of the spike. Also measure interiors, moisture, wear and surface reactions during sustained scorching.
- The one-minute 150-piece / 12-log scorching case averaged 52.4 FPS in the prior capture. Actual rendered medians at requested 16× and 64× were 10.87× and 10.42×. Keep fixed simulation steps.
- Four baseline Red Hollow scene assertions still fail. They cover opening pile picking, returning a log to the pile, the returning scout’s delivery and talking to him with another tool selected.
- Playtest Chapter II with a large reserve, active flame and twelve drying logs. Move a remote log and a near-hearth log, pull a support from a stack, bank and expose coals, then check save/reload and entry to Chapter III. For the packaged stress save, use an empty slot in a separate or existing profile and leave occupied slots intact.

## Release

The annotated tag `phase-3.4.1-playtest` identifies the mainline release commit. Resolve it with `git rev-parse phase-3.4.1-playtest^{commit}`. Use the merge commit to review the development history after branch cleanup. [PR #2 history](https://github.com/stilkar42-ui/FireTender/pull/2)

The playtest package is at `outputs/finalization-3.4.1/Firetender-Phase-3.4.1-Windows.zip`. Its build manifest records the exact mainline commit.
