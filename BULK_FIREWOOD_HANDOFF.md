# Bulk firewood playtest — 20 November 2026

Initial implementation: `b106a6f`, branch `codex/bulk-firewood-storage`, based on Echo checkpoint `118eed0` (Draft PR #3). This remains a preview, separate from the bonfire review; no merge into main. The package's `Build.txt` identifies its exact final commit, including the wet-surface readiness guard. Review: [Draft PR #4](https://github.com/stilkar42-ui/FireTender/pull/4), targeting the bonfire branch.

## Try the delivery

Unzip `outputs/bulk-firewood/Firetender-Bulk-Firewood-Windows.zip` and run **Try fuel delivery.cmd**. It opens the included **Before-fuel-delivery.sav** directly, without installing it into a player profile or replacing any save. Continue the Chapter III card and resume with Space. Rusk returns in about eight simulated seconds with nine pieces: a staged mixed dry/waterlogged deadwood load. There are already 49 bulk records, plus the existing hearth arrangement. A normal start is still `Firetender.exe`.

- **Click either pile**, **Woodpile [L]**, or **Ctrl+B** opens the stores; **B** still controls breath. Escape closes the stores.
- Choose a fuel type (or any useful piece), then draw dry fuel from the reserve or damp fuel from the rails. The piece appears individually beside the hearth; drag/place/feed it normally. Missing types give feedback rather than creating a substitute.
- Move four records between reserve and rails in one action. Reserve withdrawals require actual moisture below 34%, including wet surfaces; moving wet fuel into the reserve does not make it dry.
- **Drag unused cold fuel directly onto the reserve or drying rails.** A highlighted footprint confirms the target; releasing stores that same fuel record. Hot or burning pieces are rejected and remain where they were. Alternatively, drag unused cold fuel away from the hearth, then **Unload loose cold stock** to return it in one action. Hot fuel and placed hearth wood stay in use. The same button consolidates loose cold stock from older saves, on request.
- Rusk automatically unloads each returned armful together: dry records to the reserve, damp/wet or wet-surface records to the rails. Actual field condition is preserved; routine collection still excludes green wood.
- F5 opens normal save slots; use an empty slot. F11 loads. No launcher installs or overwrites a profile/save. The included Chapter-II-stress.sav is optional and is not installed automatically.

## Layout and physical state

The reserve occupies the sheltered left-wall alcove at (-2.04, -2.30); the low rough rails sit on the dry inner shelf at (-2.05, -3.22). Stock is now arranged in three parallel bays: tinder, sticks and limbs. Each bay shows up to 16 representative pieces; bounded pile height and exact labels represent larger stocks. Shapes remain rough and forked, with tidy stacking. A shallow bark tray sits at (-1.02, -0.68) beside the individual ready-fuel rest. The food shelf moved from x=-1.48 to x=-0.95, z=-3.56, away from the drying approach. Hunter, maker, cooking and Rusk's central approach remain clear. Five rendered entrance/hearth/work-area/storage views and floor-picking checks passed; captures are in `outputs/bulk-firewood/approach-*.png`.

The Fire Speaker gives the short storage routine in Chapter III. [Abric Romaní research](https://pmc.ncbi.nlm.nih.gov/articles/PMC13644747/) informs the wall reserve and shallow bark tray; the drying rails are our reconstruction, not an archaeological claim.

Bulk records retain each original Piece, including identity, kind/species, size, material, regional water, temperature and mass. They remain in stored inventory and use the existing sheltered ambient/weather/moisture-diffusion update at their zone. They have no individual support pose, wind obstruction or thermal graph while pooled. Drawing restores existing placement, support, airflow, thermal promotion, ignition and collapse. The thermal solver and fixed 0.25-second step are unchanged. Optional save metadata stores id-to-zone membership; saves without it load with no automatic rearrangement. No new fire-from-scratch ability was added.

## Verification

- Windows export: the actual packaged executable loaded the staged Chapter III save (49 bulk records, nine carried pieces) and the unchanged Chapter II stress save (zero bulk records), exited 0, and loaded its bundled native DLL. Profile file hashes were unchanged. Export/launch logs and DLL module evidence are in `outputs/bulk-firewood/`.
- Bulk conservation/save checks: 20/0, native and GDScript fallback. Mixed-condition sorting, transfers, missing types, return, regional drying, legacy metadata absence, binary save/reload and Rusk's in-transit delivery match. Fixture generation writes only under outputs.
- Rendered scripted loop: **27/0**. Includes mouse press/motion/release into both piles, target highlighting, hot-wood rejection, click-to-open inventory, exact type counts, switching camps at the same revision, shortcut, wet delivery, dry kindling to hearth, three damp placements, save/reload through the actual workbench loader, and five camera/floor-picking approaches. This is scripted rendered verification, not a claim of a long manual playthrough.
- Gathering 26/0; woodpile 26/0; combustion 46/0 including deterministic two-hour run; grain 30/0; construction 24/0; workbench 126/0; Chapter I–III journey 16/0; family 70/0; family scene 29/0; physical workshop 25/0; profiles/story menu 33/0.
- Native/reference comparison: 33 graphs, 32,749 ordered candidate pairs, 31,761 accepted links, zero coefficient difference; 12 active-combustion continuation snapshots match.
- Red Hollow scene: the same four pre-existing failures (opening ray-picking, returning a placed parcel, return report/delivery portrait, cousin consultation with another tool). Assertions were not changed.

## Neat display and reuse revision

`hearth/fuel_stores.gd` is a standalone display/picking component. It reads the reserve/drying positions from `fire.storage_sites`, which are persisted with optional defaults for older saves. The scene can configure its `ready_at` landing/tray location; the UI passes this through to the existing physical placement. It does not require Chapter III story data. Family props supply the camera-safe label region so counts do not draw behind the HUD. Changing camps refreshes stock even when revision counters happen to match. Use `.sync(fire)`, `.zone_at(bench, screen)` and `.highlight(zone)` in another cave/camp; keep the cold stock locations clear of the hearth. The current footprint is 0.94 × 0.72 m per pile.

At a glance, world labels show exact total/tinder/stick/limb counts. Clicking opens the type selector with each kind's reserve and drying quantities. The Fire Speaker now explains direct dragging. `PLAY.cmd` launches this current checkout.

The neat-display 150/12 spot check (20 seconds, same hardware/Compatibility resolution, Dummy audio, no regression processes competing) measured loose stock **103.5 FPS / 42.7 ms P99**, bulk stock **107.2 FPS / 30.5 ms P99**, with 16 active thermal pieces in both. This is a spot check; earlier desktop runs varied substantially. Logs: `neat-stress.jsonl`. The earlier display's measurements below are retained as history, not a promise for every play session.

Matched earlier display, 150 stored / 12 scorching, 1x, Chapter III, Compatibility renderer 1920x1016, i5-7500 / GTX 1070 Ti, 20 seconds per case, Dummy audio, no concurrent regression processes:

| Prior display run | Loose stock FPS / P99 ms | Bulk stock FPS / P99 ms |
|---|---:|---:|
| First | 69.7 / 52.7 | 55.3 / 50.7 |
| Repeat | 69.1 / 53.5 | 71.0 / 44.6 |

Both retain 150 inventory records and 16 thermally active pieces (103 nodes / 781 links); individual fuel mesh nodes fall 418 → 43. The remote stock was already thermally pruned before this change. Average FPS is variable and a reliable improvement is not established; P99 improved in both final-code runs. An earlier display prototype measured 69.9 → 80.1 FPS and is not the final implementation result.

Separate existing interaction scenarios, 10 seconds each: mass promotion to 68 active pieces peaks at **150.8 ms**; support-collapse scenario peaks at **156.5 ms**, with the measured removal action itself **59.6 ms**. These were not optimized in this storage pass. Logs/JSONL are under `outputs/bulk-firewood/`.

## Remaining issues and next review

Keep this a preview. Echo's PR #3 review identifies large-save slot-list latency and missing packed-row coal-endpoint validation; neither is changed here. Rendered promotion/collapse and fast-forward remain future profiling work. Compatibility rendering reports transient null-material warnings during scene replacement, plus an exit ObjectDB leak warning in the scripted scene run; captures remained intact and no script errors occurred. Investigate those warnings rather than treating them as a clean graphics log. Sustained frame rate varies; do not promise 60 FPS in every heavy scene.

Next: Echo review of this storage-only delta, hands-on tending with larger reserves and twelve drying pieces, then correlated frame/picking/support/combustion profiling. Preserve the original mainline release and player slots. Tests were muted after the user requested silence; subsequent rendered/exported tests use `--audio-driver Dummy` without changing saved player sound settings.
