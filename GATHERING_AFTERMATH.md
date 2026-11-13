# Red Hollow · Gathering after the storm

In Chapter II, open **Torch Bearer [F6]**. **Survey only** sends Rusk to look without collecting. **Dry wood only** asks him to bring back protected fuel for the hearth. **Logs to dry** asks him to collect medium branches or larger splits, starting with the least saturated wood he finds. Wet loads weigh more, so a trip can bring fewer pieces back.

Press **F10** to see Rusk’s observations in the Mind Cave. A report appears when he returns and shows when he saw the site and when you heard the news. A report from before the rain remains a dated record. The place’s current state can change before someone sees it again.

## Before and after

This reproducible comparison uses Red Hollow’s opening weather and default world seed. In this run, Rusk gathered every original piece at the fallen pine and eight original pieces at the ridge before the storm. The other gathering sites were untouched. The moisture columns count only pieces still available in the field.

| Site | Original | Collected before the storm | Surviving originals | Storm-added deadwood | Protected / damp / wet / waterlogged | Player knowledge at handoff |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Bark ledge | 20 | 0 | 20 | 0 | 20 / 0 / 0 / 0 | Awaiting a post-storm report |
| Fallen pine in the lee | 33 | 33 | 0 | 10 | 2 / 8 / 0 / 0 | Awaiting a post-storm report |
| Far oak ridge | 15 | 8 | 7 | 6 | 0 / 2 / 11 / 0 | Awaiting a post-storm report |
| Watch the sky path | 0 | 0 | 0 | 0 | 0 / 0 / 0 / 0 | Awaiting a post-storm report |
| Standing dead birch | 13 | 0 | 13 | 7 | 6 / 13 / 1 / 0 | Awaiting a post-storm report |
| Willows in the hollow | 9 | 0 | 9 | 5 | 0 / 0 / 0 / 14 | Awaiting a post-storm report |

The birch survey in the rendered review records six protected, thirteen damp and one wet piece. Rusk sees them at Day 4 · 0:25 and reports them at Day 4 · 0:50. The survey leaves the inventory in place. Asking Rusk to bring logs afterward removes specific pieces at pickup and records a new observation. The shelter’s placed wood then dries or burns using its actual moisture, temperature and grain.

[See the Chapter II birch report in the Mind Cave](outputs/ui-review/phase33/phase23-reported-birch.png)

## World state and saves

`sim/gathering_sites.gd` owns the field inventory and resolves named weather events. Each piece has a stable ID within its site, original and current moisture, exposure history, an origin event for new stormfall, and a collection record. Rain, duration, prevailing wind, gusts, terrain, and the world seed affect the result. The opening chapter samples its authored storm and applies it once before Chapter II. Later weather can use the same entry point.

The save keeps the event key, site inventory, Rusk’s planned or collected load, and the observed reports. Chapter III shares the Mind Cave records from Chapter II. Legacy saves retain depleted stock and active trips. Legacy Chapter II and III saves use the old delivery moisture rules when migrating field stock and keep their existing shelter stormfall.

The chapter’s one-time shelter supplies keep the four-log lesson reachable after heavy spending in Chapter I. Field deposits are finite deadwood. Fresh green wood remains a Chapter IV subject.

Run the comparison and save checks with:

```powershell
godot --headless --path . --script res://tests/gathering_sites_checks.gd
```
