# Mind Cave

Press **F10** in Chapter III or choose **Mind Cave** below the shelter controls. The **Territory** view lays out the paths around Red Hollow. **Inside Red Hollow** shows the cave mouth, hearth, shelves, seep, and working places. Select a place to read the sightings and reports associated with it. Interior selections center the existing cave camera. Work areas also record materials you saw or heard about there, including the hunters’ catch and the food Nara receives. **Look here in the cave** closes the page so you can see the selected area.

Select a family member with **F9**, then choose **Find in Mind Cave**. The selection marks their last known place. A person mark opens that person’s Family Tree entry. A group mark opens its place list, where each name has its own link. The latest located item in **Shelter news** has a portrait and a link to the place.

## Reading the marks

| Mark | Meaning |
| --- | --- |
| Figure in a solid ring | A recent sighting. A number counts the people associated with the place. |
| Figure in a broken ring | An older sighting, an absence, or a traveller’s intended destination. Read the list for each person's status. |
| Dots between places | A known path. An ochre trail highlights a departure you witnessed or learned about. |
| Branch | Wood, fibres, or a resin source. |
| Hoofprints or deer | Game sign or a hunting place. |
| Sun, wind strokes, or falling rain | Weather that was visible or reported. A broken rim identifies an older report. |
| Triangle | A reported concern such as dwindling fuel, an injury, or smoke at a work area. |
| Limestone arch, flame, or ripples | The shelter, hearth work, or water. |
| Bowl, flaked point, or bone | Food preparation or storage, hafting, or game processing. |

Reports show the observer and when they saw something. If you heard it later, both times appear. The mark ages after 105 seconds on the hearth clock. Old news stays on the page until someone sees or reports a newer observation. A departure leaves a sighting at the shelter and a separate mark of intent at the destination. A sighting on the trail or a witnessed return can change the last known place.

## Adding people and places

1. Add a person to [family_roster.gd](sim/family_roster.gd) with a stable ID, kinship, role, opening activity, and a place name the map knows. Use that ID for the art file in [hearth/art/family](hearth/art/family). The Fire Speaker and Rusk use legacy paths in [family_portraits.gd](hearth/family_portraits.gd).
2. Add the person’s card position and any branch connectors in [family_page.gd](hearth/family_page.gd). Keep the parent and partner links in the roster aligned with the drawn branches. Test the card at the default window size and open its map link.
3. Add a place to the appropriate collection in [family_land.gd](sim/family_land.gd). Give it an anchor on the drawing, a symbol from [mind_marks.gd](hearth/mind_marks.gd), a short map label, and a remembered description. Add a camera coordinate for an interior place. For a new field site, connect it to the corresponding simulation data and any route or landmark links.
4. Record changes when a person witnesses them or when a report arrives. Send a stable place name and topic, a short report, the source, the observation time, and the time the Ember Tender learned it. The Mind Cave reads that record and the same known-person snapshots as the Family Tree. Keep private movement, encounters, resource amounts, and decisions in the simulation until they are observed.

## Review images

[Family Tree with Nara](outputs/ui-review/phase31/family-tree.png) · [Nara’s Cooking Place](outputs/ui-review/phase31/inside-red-hollow.png) · [Rusk’s gathering path](outputs/ui-review/phase31/rusks-gathering-path.png) · [Returned report](outputs/ui-review/phase31/shelter-news.png) · [Territory and weather report](outputs/ui-review/phase31/mind-cave-territory.png)
