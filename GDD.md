# Firetender · Game Design Document

- **Playable scope** · Red Hollow, Chapters I–III
- **Format** · Single-player, offline, 3D hearth simulation and story
- **Current platform** · Windows PC with mouse and keyboard, built in Godot

## Premise

The Ember Tender is entrusted with a single rescued coal. A storm is coming to Red Hollow, a limestone shelter shared by Stone Mountain’s kin. The player learns to build a fire, preserve its coals, and make useful heat for the household. The Fire Speaker teaches from beside the hearth. Rusk, the Torch Bearer, gathers supplies and brings news from the paths.

## Design pillars

| Pillar | What the player does |
| --- | --- |
| Build a fire before lighting it | Lay a tinder nest, leave gaps, and choose how the small and large fuel fits together. Carry an ember into the prepared tinder and watch the flame work its way through the structure. |
| Read the fire and its shelter | Use smoke, steam, sound, coals, weather and inspection to decide where to build, when to feed the fire, and what to protect from rain. |
| Put heat to work | Dry wet wood, roast food, and warm resin. Each job asks for a different relationship to flame, coals and airflow. |
| Learn from family and practice | Ask the Fire Speaker, observe a specialist and try the work on actual materials. Record what was learned in dialogue, the quest journal and the family’s technique records. |

## Play loop

1. **Assess.** Read the weather, remaining wood and the condition of the hearth. Check the quest journal or ask the Fire Speaker when a signal is unfamiliar.
2. **Prepare.** Gather fuel by sending Rusk to a known location. Sort the load under cover, arrange timber and work tinder into a bundle when needed.
3. **Build and tend.** Place fuel in 3D, carry an ember, direct a breath or rake coals. Feed from an open side as the structure burns down. Sweep loose ash and bank a living bed when the fire can rest.
4. **Use the heat.** Place materials where the task needs warmth. Inspect the result and adjust the distance, spacing or time.
5. **Review.** Read the chapter results and the supplies on hand. Carry the hearth and the consequences of earlier choices into the next chapter.

Time can be paused while building. The player can resume at 1× or use acceleration and short jumps to observe a process. Weather, travel, crafting and combustion advance on the same hearth clock.

## Chapter progression

| Chapter | Player objective | Handoff |
| --- | --- | --- |
| **I · Red Hollow** | Build from the rescued ember. Stock three dry tinder parcels, six pieces of dry kindling, two medium logs and two large logs under cover by the first rain. Keep living fire through the storm and the end of Day 3. | Results record readiness and survival separately. A surviving hearth can enter Chapter II even if the reserve fell short. A cold hearth offers a retry or an earlier save. |
| **II · After the Tears of the Sky Father** | Dry one medium and one large log on the sheltered shelf. Dry a second pair beside the fire without scorching it. Keep living coals while all four goals are completed. | Results show each method and size, plus supplies on hand. Continue into Chapter III on the same hearth and clock. |
| **III · The Work of the Family** | Keep useful heat available as the family responds to a fallen bison. Observe or help Bera extract marrow, Nara roast meat and Ina prepare resin or repair a haft. | The family’s work, learning and material state continue in the playable chapter. |

Chapter II targets **20–30 minutes of hearth time at 1×**. The tested route completed in about 21 minutes. The player can start both drying methods in parallel.

| Method | Typical Red Hollow timing | What the player learns |
| --- | --- | --- |
| Air-dry on the back-left shelf | About ten minutes for a medium branch and twenty for a large split | Space the logs and keep them clear of the seep. Air drying is slower and the risk of scorching is low. |
| Warm outside the fire ring | A few minutes beside a steady fire | Wake the fire with dry fuel. Turn and inspect the wet logs. Pull them back if they start to scorch. Wet fuel placed in the bed draws heat from the coals. |

These timings are tuned to the game’s clock. Dry outer faces can hide a wet core. The four drying objectives use distinct logs and credit the method that removed most of the moisture.

## Player systems

| System | Design |
| --- | --- |
| **Fire construction** | Logs have mass, shape, support, orientation and separate moisture and heat readings through the grain. Cold structures can be built before ignition. Contact, airflow, radiant heat and fuel condition shape how fire spreads. Blueprints remember cold layouts for rebuilding with available fuel. |
| **Gathering and weather** | Gathering sites have finite supplies, travel times and weather constraints. The chosen hearth location changes shelter from rain, wind and smoke. Ash cover preserves a coal bed for later work. |
| **Crafting** | The crafting page uses the Mind Cave’s visual language. Two parcels of any supported raw tinder can be worked into one tinder bundle in eight hearth seconds. The finished bundle retains their moisture. |
| **Quests and teaching** | The journal gives chapter goals, progress and shortcuts to relevant locations. Chapter I measures dry fuel physically under cover. Chapter II tracks each log and its drying history. Suggested and typed questions work offline, and the Fire Speaker’s lessons can be reviewed. |
| **Family and place** | Workstations use real tools and finite materials. Family members act independently and ask for heat when needed. The Family Tree records kinship and techniques. The Mind Cave shows witnessed places and reports, including when the information was learned. |
| **Profiles and saves** | Start, Continue, Load, Settings and Exit appear on the launch screen. Five profiles each have ten local save slots. Chapter transitions checkpoint the active story slot, and loading restores the hearth and quest progress. |

## Presentation

Keep the player in one connected 3D shelter and its immediate landscape. Daylight, rain, drafts and firelight change the view of the same physical space. Use the painted valley, ochre marks, stone textures and warm, restrained panels across the story and tools. Smoke, steam, embers, crackle and weather give the player feedback, with separate volume controls for fire and weather. Keep the Fire Speaker’s dialogue near his seat and leave room for tending controls.

## Playtest criteria

- A cold log cabin built from owned fuel can catch from a prepared tinder bundle and carried ember. A blueprint can reproduce the arrangement with available stock.
- A complete Chapter I run records the reserve when the rain starts and gives its results at the end of Day 3. The next chapter opens on Day 4 with the inherited hearth.
- A Chapter II run can finish in 20–30 minutes at normal pace. A player can explain the timing and tradeoffs of both drying methods after hearing the Fire Speaker and trying them.
- Scorching, reheating, moving and saving logs behave consistently. Saving mid-quest preserves progress, and the Chapter III loading page appears after Chapter II’s results.
- In Chapter III, heat requests arise from actual work. The player can observe a specialist and apply the lesson to a real material.

## Project references

- [Run the game, controls and test commands](README.md)
- [Chapter III work and apprenticeship](CHAPTER_III_WORK.md)
- [Mind Cave map and reports](MIND_CAVE.md)
- [Combustion behavior and test evidence](BURN_AUDIT.md)
