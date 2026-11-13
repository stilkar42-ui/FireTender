# Firetender burn-time audit

These measurements record the burn-rate update before Phase 1.7. The current nursing-ember trials and their charcoal heat-balance changes are documented in the README.

## Measured in the hearth

Each run put one room-temperature fuel item at the center of the same sheltered bed of six 145 g charcoal patches at 700 °C. Fuel used its default moisture. The clock starts at placement and advances in 0.25 s steps. The audit records the first and last steps above a flame-power threshold, the total time above it, and the time to 50% and 90% dry-wood conversion. The threshold is 20 kW/kg of starting dry wood, bounded between 0.25 and 2 kW. Conversion includes decomposition into gas and char. Char can keep glowing after the flame ends.

| Fuel | Dry mass | Water / dry mass | First flame (s) | Flaming time before → after (s) | Time to 90% conversion before → after (s) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bark fibres | 3.2 g | 3.5% | 0.75 | 4.25 → 4.25 | 3.75 → 3.75 |
| Dry grass | 4.2 g | 5.5% | 1.00 | 4.75 → 4.75 | 4.50 → 4.50 |
| Birch bark | 21.0 g | 4.5% | 1.00 | 2.75 → 2.75 | 2.25 → 2.25 |
| Pine twigs | 71.0 g | 8.0% | 1.00 | 6.75 → 6.75 | 5.75 → 5.75 |
| Dry splinters | 8.5 g | 6.7% | 1.00 | 5.75 → 5.75 | 5.25 → 5.25 |
| Finger sticks | 42.0 g | 8.0% | 1.00 | 9.00 → 9.00 | 8.00 → 8.00 |
| Split branch | 140.0 g | 10.5% | 3.00 | 26.00 → 34.25 | 25.25 → 32.50 |
| Pine branch | 208.5 g | 14.0% | 3.50 | 27.75 → 43.25 | 27.25 → 40.50 |
| Birch branch | 268.8 g | 18.0% | 4.75 | 40.75 → 64.00 | 40.00 → 59.75 |
| Willow branch | 184.9 g | 31.0% | 4.00 | 28.00 → 42.50 | 28.00 → 40.50 |
| Thick branch | 260.0 g | 13.0% | 3.50 | 41.00 → 63.25 | 39.00 → 57.75 |
| Split oak | 380.0 g | 13.0% | 5.25 | 64.00 → 108.25 | 61.75 → 99.75 |
| Long split | 540.0 g | 15.0% | 4.75 | 78.00 → 141.25 | 71.75 → 126.00 |
| Wet oak | 460.0 g | 86.0% | No flame | 0 → 0 | 98.9% of wood remained at 20 min |

With no added fuel, One Ember's 12.5 g coal stayed above 370 °C for **10.5 s**. The hottest part of a raked 665 g bed stayed above that threshold for **2 min 5 s** exposed and **21 min 20 s** banked. These are temperature readings. The ash can hide coals that are still hot enough to recover.

## Comparison with published measurements

- **Tinder and starter.** Firetender's separate portions flame for about 3–7 s on a strong coal bed. In a radiantly heated test, 5 g of dry maritime pine needles flamed for about 16 s and 10 g for 32 s. Grass experiments also found that moisture and fuel mixture change flaming duration. These are scale comparisons for fibrous fuel. Bark, grass, twigs and needles have different exposed areas and packing. [Fuentes et al., pine-needle fuel layers](https://www.combustion-institute.it/proceedings/MCS-7/papers/FE/FE-21.pdf), [laboratory grass burns](https://link.springer.com/article/10.1186/s42408-024-00338-z)
- **Splinters, sticks and branches.** Firetender's loose splinters and finger sticks flame for about 6–9 s, and its branches now flame for roughly 34–64 s. Gardner and Blunck measured about 30 s to over 200 s of flaming for solid stems as diameter rose from roughly 8 to 20 mm under their heated test conditions. The game's bundle envelope includes air gaps, and its branch shapes and heating differ. The data support a slower progression with increasing thickness while leaving exact species matches uncertain. [Gardner and Blunck, stem ignition and flaming](https://journals.sagepub.com/doi/10.1177/07349041251327436)
- **Splits.** The game's dry oak splits now reach 90% conversion in roughly 1.7–2.1 min. In a study of a single large log in a natural-draft stove, pyrolysis was nearly over at around 30 min. Tests on small logs also reported substantial variation in ignition time at the same radiant heat flux. The game still compresses log timescales. The stove geometry, air supply and log size make 30 min a poor direct target for this hearth. [Anca-Couce et al., single-log stove tests](https://tugraz.elsevierpure.com/en/publications/single-large-wood-log-conversion-in-a-stove-experiments-and-model/), [Hu et al., small-log fire tests](https://jst.tsinghuajournals.com/EN/10.16511/j.cnki.qhdxxb.2022.22.035)
- **Wet oak and coals.** Live Douglas-fir stems near 90% moisture on a dry-mass basis took about 142–636 s to ignite in the sustained laboratory exposure. The game's saturated oak on a finite bed never reached the flame threshold in 20 min. Experiments with burning wooden particles also distinguish flaming from later char oxidation and show that airflow changes both stages. Those tests use different materials, sizes and oxygen conditions from the banked hearth. [Gardner and Blunck, moisture trials](https://journals.sagepub.com/doi/10.1177/07349041251327436), [firebrand burning experiments](https://doi.org/10.1071/WF23151)

The adjustment adds resistance as the char layer develops on larger wood, with a stronger effect on thicker pieces. It preserves measured first-flame times in the hot-bed test and slows later conversion. The small fuels and charcoal use their existing rates.

Run the audit with `godot --headless --path . --script tests/burn_audit.gd`. In the output, `-1` means a threshold was never reached. Length and diameter are model-envelope measurements.
