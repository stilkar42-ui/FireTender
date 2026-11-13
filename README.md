# Firetender · Phase 3.2 · The Work of the Family

Bring a rescued ember back to flame with the Fire Speaker beside you. Keep the living hearth for Stone Mountain’s kin through the storm at Red Hollow.

[Game design document](GDD.md)

## Run

Open **PLAY.cmd** on this PC, or open **project.godot** in Godot 4 and press **F5**. Verified with Godot 4.7.2 and the Compatibility renderer.

To make a Windows Godot pack, create an `outputs` directory and run `godot --headless --path . --export-pack "Windows Desktop" outputs/Firetender.pck`. Run it with `godot --main-pack outputs/Firetender.pck`. The source and pack both run offline.

Firetender opens at the launch page with **Start**, **Continue**, **Load**, **Settings**, and **Exit**. Choose one of five profiles and rename it if you wish. Each profile has ten story save slots. **Start** uses the first empty slot, **Continue** resumes the latest save for that profile, and **Load** lets you choose a specific slot. **F5** and **F11** open Save and Load from the hearth. Chapter transitions checkpoint the current story slot. An existing single Chapter III save appears in Profile 1, Slot 1 until that slot has its own save. Use **Menu** to return to the launch page.

At the hearth, **F1** starts a fresh Chapter I, **F2** opens the original apprenticeship practices, and **F4** opens One Ember. **Test hearths** opens the other experiments. **H** rereads the Speaker’s words and offers a retry during practice.

[Launch page](outputs/ui-review/launch/launch-menu.png) · [Chapter I](outputs/ui-review/launch/chapter-i-loading.png) · [Chapter II](outputs/ui-review/launch/chapter-ii-loading.png) · [Save browser](outputs/ui-review/launch/profile-save-browser.png)

## Build a fire before you light it

Press **P** to open **Crafting**. Choose two separate parcels of bark fibres, dry grass, leaves or birch bark in any combination. **Work bundle** takes eight seconds on the hearth clock. **Wait for bundle** advances the remaining time, and **Stop work** releases the ingredients. A finished bundle keeps the ingredients’ moisture. Choose **Take bundle to the hearth** to place it. [Crafting page](outputs/ui-review/crafting/crafting-menu.png)

In **Test hearths**, choose **Build · Cold log cabin**. The frame and kindling start cold, with an ember set aside. Put the bundle at the base of the cabin, drag the ember into it with **C**, and let time run. Use **B** for a gentle breath if the glow needs air. You can also build by hand in One Ember practice or in the story. Leave an inlet low in the stack and space for heat to rise. Dry splinters and finger sticks bridge the gap between tinder and the heavier rails.

Press **F12** to name and save the cold layout. Open **Blueprints** on an empty hearth to rebuild it. The plan keeps fuel types, spacing, angles and layers. Story rebuilding moves matching pieces from the actual woodpile, with their current moisture and temperature. Gather any missing fuel or prepare a new tinder bundle before rebuilding. Place your own ember afterward.

The model uses side openings and upward gaps to distinguish ventilated builds from densely packed ones. That distinction is informed by NIST’s crib-fire experiments, where greater packing density reduced peak heat release. [NIST crib-fire study](https://www.nist.gov/publications/burning-characteristics-and-smoke-emission-mixed-fuel-cribs)

[Cold cabin](outputs/ui-review/cold-builds/cold-cabin.png) · [Blueprint library](outputs/ui-review/cold-builds/blueprint-library.png) · [The rebuilt cabin burning](outputs/ui-review/cold-builds/cabin-burning.png)

## The opening chapter

Red Hollow is the shelter. Its people call themselves Stone Mountain’s kin. The Fire Speaker is your mother’s brother and was the Fire Tender before his injury. The Torch Bearer is your cousin, the child of your mother’s sister. The story takes place about 70,000 years ago in what is now southwestern France. The ancestor’s English name, these family relationships and the band of fifteen are fictional choices. The count belongs to the chapter data and the characters speak about their kin.

While paused, choose **Inner shelf**, **Under the lip**, or **Open mouth**. Choosing the site moves the work area relative to the shelter while you have a single portable coal and no built fire. The inner shelf catches more smoke and the mouth admits more rain and gusts. Watch for a turning wind even when the mouth looks clear. **Under the lip** offers some cover and a shorter path for smoke.

The same shelter menu also focuses the deep dry shelf, tinder alcove, warming edge, seep, and air passage. These areas are accessible from the start, and you can place and move physical fuel in them. The camera destinations stay available once the hearth site is committed.

Click the Torch Bearer on the left or press **F6** to hear his survey. Choose a route and a mixed armful or a tinder, kindling, or larger-wood priority. The fallen pine in the lee has kindling and branches for the first fire. Save some tinder and consider the oak ridge while it is still passable. The ridge needs daylight, and rain can close paths, delay travel, or soak a load. His portrait disappears while he is out. On return, his report tells you what he found and how much is likely to be left. Every armful draws from the site's remaining supply.

Press **L** to center the woodpile. Drag pieces between the pile and the hearth, cross logs over one another to stack them, or drag them apart to sort them. **F** focuses a selected piece and **Home** restores the wide view. Choosing a fuel slot in Red Hollow selects a piece from outside the hearth. Placing it takes that piece from its old rest. A returned log keeps its moisture, temperature, burn damage, and remaining material. Store dry fuel under cover and leave space between the pile and the coals.

Ask the Fire Speaker **“What should my cousin bring?”** with **G**. He makes two specific recommendations when the Torch Bearer is available and there is a reachable source to suggest. Each choice is recorded for the current chapter. After the second, he leaves the decision to you. He still answers questions about what different fuels can do, how the fire is doing, and how to prepare for the storm.

Lay loose fibres, use **C** to carry the coal into them, then use **Space** or **+2 seconds** to advance and **B** to aim a gentle breath. Feed small pieces first. Give larger wood time to catch, and watch the red collect underneath. **Y** sweeps ash from burned patches or loose piles. Drag it aside to make a pile or drop it onto a coal to cover that spot. **Bank with ash** sifts from loose piles, and **Expose coals** brushes the cover back aside. Ash comes from the material that burns.

Each story day lasts **six minutes of hearth time**, with daylight and night compressed to match the current fuel and charcoal lifetimes. All fire reactions still use the fixed quarter-second steps. Use the speed picker and time jumps when the bed is stable. Banking conserves warmth, but check the red before the strongest rain and use reserved dry tinder if it needs waking. To finish, establish a coal bed, keep coals under ash for a sustained rest, and carry living fire through Day Three. A cold hearth can be replayed with **F1**.

Ask the Fire Speaker with **G** about the storm, the shelter, ash, the fire he brought back, or your family. The same offline understanding and dialogue history carry into the chapter.

## Chapter II · After the Tears of the Sky Father

Open **Quests [O]** in Chapter I to track your storm reserve and living fire. Have three parcels of dry tinder, six pieces of dry kindling, two medium logs and two large logs under cover when the rain arrives. At the close of Day 3, the results show how you did and what supplies you have on hand. If fire survives, choose **Continue to Chapter II**. The loading page opens on Day 4 with the same hearth, supplies and dialogue. If the fire goes out, retry or load an earlier save. **F7** opens a separate Chapter II practice start.

- Start a medium log and a large oak split on the back-left dry shelf. Space the logs so air moves between them. The journal can focus the camera on the shelf or the warming edge.
- Wake the living coals with dry tinder and kindling. Set another medium log and large split just outside the ring, alongside the fire. They dry faster there, with a greater risk of scorching. Use **Wet wood** to find the actual wet logs and **Inspect [I]** to check moisture at the core.
- Keep dry tinder on the protected left side. When a heated knot or pocket pops, follow the little jumping flame and watch the spot where it lands. A hot fragment can start a fire in dry tinder. Move vulnerable fuel away from the fire and its draft.
- Keep living coals until all four logs have dried. The journal checks moisture through the log, and a piece that scorches before its drying goal is recorded has to be replaced.

The Speaker tells the story of the Mother of the World, the Sky Father, and their sons Aru and Varek in passages as you work. Ask with **G**, or open **H → Read the tale** for the full story. This mythology is fictional.

The Fire Speaker opens Chapter II with the drying lesson. In Red Hollow a medium log takes about ten minutes on the shelf and a large split takes about twenty. Beside a steady fire they take a few minutes and can scorch if left too close. Ask with **G** to hear the comparison or either method again.

After the storm, use **F6** to ask Rusk to survey a route, gather protected fuel, or bring logs to dry. His reports appear in the **Mind Cave [F10]** when he returns. [Gathering sites and the before-and-after comparison](GATHERING_AFTERMATH.md)

[The opening](outputs/ui-review/phase23/phase23-opening.png) · [The deep interior](outputs/ui-review/phase23/phase23-deep-interior.png) · [The tale](outputs/ui-review/phase23/phase23-tale.png)

### Matched views across the chapters

| Camera position | Chapter I | Chapter II |
| --- | --- | --- |
| Hearth toward the rear chamber | [Chapter I](outputs/ui-review/phase231/chapter-i-hearth-to-rear.png) | [Chapter II](outputs/ui-review/phase231/chapter-ii-hearth-to-rear.png) |
| Rear chamber toward the entrance | [Chapter I](outputs/ui-review/phase231/chapter-i-rear-to-entrance.png) | [Chapter II](outputs/ui-review/phase231/chapter-ii-rear-to-entrance.png) |

## Chapter III · The Work of the Family

When Chapter II ends, its results show all four drying goals and the supplies on hand. Choose **Continue to Chapter III** to see its loading page and carry the same cave, hearth, weather, woodpile, gathering sites and conversation history forward. **F8** opens a separate practice start with a live coal bed and the chapter’s opening supplies. **Space** resumes time, and **+2 seconds** is useful when checking a roast or resin cup.

- **Hunter’s Working Place** has a finite game portion to start. Select it and separate the cuts. Crack a marrow bone, carry meat or marrow to Nara, or cut a strip of hide for the Maker’s Stone. The hunters’ spears can be inspected here when they are home.
- **Cooking Place** takes a cut from Nara’s board and puts a portion on the spit. Pick a rest for the spit, turn it as the first face browns, and lift it once it is roasted through. The covered shelf takes the actual portion. Undercooked portions can go back on the spit. Dry, overcooked food can still be eaten. Charred food can be discarded.
- **Maker’s Stone** has a resinous knot. Scrape it into the cup, warm it gently, and lift it when the resin runs evenly. Bind a loose haft with adhesive and rawhide, or fit a fresh shaft and point to replace a damaged one. Strong heat can scorch the resin and send smoke into the shelter.
- Select a work area from the shelter menu or click its label in the cave with the ordinary wood tool. The work panel leaves the hearth and time controls available.
- **F9** opens the Family Tree. Select any of the fifteen members to read their kinship, work and last known activity. **News at the shelter** shows who told you and when. Rusk still brings wood through **F6**. He passes on the elders’ decisions and news he learns at home or on the path. Other kin can speak when they have news of their own.
- **Ember Tender** shows the four specialties and techniques learned through completed work. A kept bed, a recovered flame, a roast, usable adhesive and a sound haft each teach through the existing simulation.

Rusk brings word of a bison below a broken ledge. The elders decide when to send carriers, and each trip brings home a limited load. Scavengers and spoilage diminish what the family can use. Bera, Nara and Ina work the available materials independently. Nara and Ina ask for heat when their work needs it, and both use the existing hearth.

### Physical work and family lessons

Click or drag materials in the cave. Click once to carry an object between work areas, then click where you want it to rest. **I** inspects the material under the pointer, **V** works it, and **Esc** puts a carried item back. At a bench, choose **Observe**, **Learn** or **Help**. The **Techniques** page in **F9** keeps what you’ve learned. Tell Eren what you did through **G**. [Work controls and seven gameplay examples](CHAPTER_III_WORK.md)

### Family portraits and the Mind Cave

The Family Tree shows a portrait for each of the fourteen relatives. **Find in Mind Cave** marks the selected person’s last known place. Press **F10** to open the symbolic territory drawing or switch to the interior of Red Hollow. Select places for reports, click people to return to the Family Tree, and use **Look here in the cave** to return to the world at an interior place. [Symbol legend, examples, and authoring notes](MIND_CAVE.md) · [Portrait files and prompts](hearth/art/family/README.md)

Chapter III continues while the family works and rests. Fire from scratch belongs to the future third narrative act. Red Hollow still depends on living fire carried and preserved.

## Reading the valley and preparing the hearth

Red Hollow opens facing the hearth from beneath the limestone roof. **Right-drag** orbits the current focus. Pan with **WASD** or **middle-drag** to move the whole view through the mouth and onto the rocky shelf. From there, orbit back toward the cave entrance or tilt up to the stars. The wheel zooms, **F** centers the orbit on selected fuel or the ground under the cursor, and **Home** returns to the hearth. On a clear first night, look for the Milky Way around **05:30** on the chapter clock.

The upper-right weather readout pairs the state of the sky with what reaches the hearth. Look for these cues as the chapter passes.

| What you see | What it tells you |
| --- | --- |
| A bright horizon, or stars and the moon on a clear night | Daylight is fading or returning. Clear gaps give you time to bring wood under cover. |
| Cloud layers gathering over the ridge | The front is building. The paths can still be dry while the cloud thickens. |
| A grey rain curtain below the cloud | The rain line is approaching. Move the dry reserve back from the drip line. |
| A dark sky, slanted drops, and smoke leaning back under the rock | A long wet stretch asks for a larger reserve. Check how far drops and smoke reach at your chosen hearth site. |
| A thinning rain curtain | The worst is passing. Check the bed before spending the dry fuel you set aside. |

With **G**, choose **What does that sky tell you?** or **Do we have enough for the weather?** You can ask about one supply in your own words, such as “Will our splits last through the storm?”, “Have we enough ash to bank the coals?”, or “Are these coals strong enough for a rest?” The elder also points out new weather cues during the chapter when he has room to speak.

His estimates account for remaining dry tinder, small wood, branches, and larger splits separately. Wet fuel and wood left where rain can reach it contribute less. He reads the heat and strength of the coal bed, and compares loose ash and existing cover with the living patches. A reserve that can carry a short shower can fall short during a sustained front. Asking for this assessment leaves both gathering consultations available.

The limestone shelter sits on an uneven rock shelf with weathered pines, scrub, and grass. The painted foreground and distant horizon sit beyond the shelf at different depths, giving a visible shift as you pan. The native sky blends into the horizon and follows the same day, moon and storm as the fire. Red Hollow’s scenery resource supplies the cave, exterior ground and vegetation, and both paintings to the shared workbench. [How to author another location](hearth/art/README.md)

### Visual review

- Red Hollow outcrop [cave from outside](outputs/ui-review/outcrop/outcrop-cave-exterior.png), [shelf and valley](outputs/ui-review/outcrop/outcrop-shelf-valley.png), and [overhead stars](outputs/ui-review/outcrop/outcrop-zenith.png).
- Full orbit and bottom-left controls [hearth view](outputs/ui-review/phase223/phase223-hearth-daylight.png), [side view](outputs/ui-review/phase223/phase223-side-orbit.png), and [rear wall](outputs/ui-review/phase223/phase223-rear-wall.png).
- Hearth view [daylight](outputs/ui-review/phase222/phase222-hearth-daylight.png), [dusk](outputs/ui-review/phase222/phase222-hearth-dusk.png), and [night with firelight](outputs/ui-review/phase222/phase222-normal-night-firelight.png).
- Lookout [daylight](outputs/ui-review/phase222/phase222-lookout.png), [moonlight](outputs/ui-review/phase222/phase222-lookout-night.png), [approaching rain](outputs/ui-review/phase222/phase222-rain-line.png), and [rain at the mouth](outputs/ui-review/phase222/phase222-storm.png).
- Framing checks at [maximum zoom](outputs/ui-review/phase222/phase222-maximum-zoom.png) and low orbit [left](outputs/ui-review/phase222/phase222-low-orbit-1.png) and [right](outputs/ui-review/phase222/phase222-low-orbit-2.png).

## Hearth layout

The hearth fills the application window. Building tools float at the upper left, and the illustrated fuel bar runs along the bottom. The painted hand and last inspection sit at the lower left. The Fire Speaker, consultation, and dialogue history sit at the lower right. Weather, time, test hearths, and **Readings [F3]** sit at the upper right. Find the separate Fire and Weather volume sliders under **Settings**.

In Red Hollow the Torch Bearer and the hand icon sit against the bottom-left edge. The Torch Bearer’s button is below his portrait and Last Inspection sits above the hand readout. When the cousin is away, his button opens his travel status. The fuel bar makes room for both the corner controls and the Speaker’s question box when it opens.

Soft edge shading keeps text readable while showing the scene underneath. Active tools and materials use warm outlines and the current fuel group has an ember-colored underline. The fuel tray, Settings, developer readings, and scrollable Speaker history use stronger backgrounds for longer reading.

## Workbench controls

| Control | Action |
| --- | --- |
| **W / A / S / D** or **middle-drag** | Pan the camera and its focus horizontally. |
| **Right-drag**, **wheel** | Orbit the focus or zoom. Drag upward past the horizon to look at the sky. |
| **Shift + middle-drag** | Raise or lower your viewpoint for a closer look at the fuel. |
| **F**, **Home** | F centers the orbit on selected fuel or the ground under the cursor. Home restores the starting focus, angle and zoom. |
| **Fuel tabs**, **1–9**, **0**, **-**, **U**, **J**, **K**, **M** | Switch groups and click an illustrated slot, or press the key shown on the slot. Shortcuts also open the matching group. M opens the full tray. |
| **Tab** | Recall the last fuel. Press again while placing to return to the previous tool. |
| **Click** or **drag and release** | Place fuel at the preview, select a piece, or move it to a new rest. Drag a piece clear of its neighbors to separate it. |
| **Q / E** | Rotate selected or previewed fuel horizontally. Choose **Fixed increments** (15° per press) or **Smooth while held** in **Settings**. **Alt** gives 5° increments or a slower smooth turn. **Alt + wheel** also turns fuel. |
| **Shift + Q / E** or **Shift + wheel** | Raise one end and lower the other in the proposed lean. A supported pose seats against actual wood, ground, or coal ridges. |
| **Ctrl + Q / E** or **Ctrl + wheel** | Choose a lower or higher rest among overlapping pieces. Up or **E** raises it, down or **Q** lowers it. |
| **N** | Toggle snapping to a fine placement grid and the axis of the support you point at. Turning snapping off uses the actual ray hit. |
| **T**, **R**, **B** | Roll a log by clicking it, drag coals to a new spot, or aim a breath. In rake mode, **Shift-drag** splits a charcoal patch and moves half. |
| **B**, **click**, **drag** in breath mode | Click to aim the first breath or drag from where you blow to the coals. Hold longer before releasing to set a longer breath. Start with **Shift** for a hard gust. After the aim line turns ochre, **B** or a click repeats the saved angle, strength, and duration. Resume time to watch the coals brighten. |
| **C** | Lift an existing ember, carry it over the hearth, and release it into loose tinder or open ground. Esc returns it to a safe nearby spot. |
| **X** | Feed sticks beneath larger wood. Choose a stick, aim its leading tip, then use the **wheel** or **Up/Down** to slide inward or withdraw. **Ctrl+Q/E** or **Ctrl+wheel** adjusts height, **Shift** adjusts tilt, and **Q/E** adjusts yaw. **Alt** makes smaller adjustments. Click to commit the preview, or select an inserted stick to slide it again. |
| **Esc** or a short right-click | Cancel the current tool or preview. |
| **Space**, **+2 seconds**, time controls | Pause or resume. Advance in small steps while building or use the weather, time jumps, and speed controls. **Space** or **Esc** stops a time jump. |
| **Hover**, **I**, **F3**, **Shift+F3** | Read surface warmth and moisture at the cursor, record an inspection, inspect the selected piece's heat ledger, or toggle the local 3D thermal overlay. |
| **G** or **Ask Speaker** | Open consultation, then click a suggested question or type a short one and press **Enter**. **Esc** closes the panel. |
| **H**, **F2** | Open the Speaker's words and retry the current practice, or start the original apprenticeship again. |
| **F1**, **F6**, **L**, **Y** | Replay Red Hollow, consult the Torch Bearer, look toward the woodpile, or drag ash in the story hearth. |

The dotted axis shows the proposed seat. Gold dots mark raised contacts and dashed drops show their height above ground. Releasing commits the pose. **Rake coals**, **Bank with ash**, and **Expose coals** work across all practices and experiments. Loading a fresh hearth returns the camera to its full-hearth view.

The ochre figure above the Torch Bearer reads the air at the camera's position. Wind marks build and fade with the draft. The caption tells you where it comes from relative to the way you're facing, including wind coming from behind when you look in from the cave mouth. **Settings → Invert wind indicator** points the marks back toward the source. The direction caption and world airflow stay the same.

Wind enters Red Hollow through the mouth and fades toward the rear. The side passage channels incoming air when the mouth takes a draft. Wind blowing past or away from the opening leaves the interior sheltered.

Wind bends flame tips while the base stays on the burning fuel. Smoke comes from the combustion model, rises in drifting parcels, spreads under the ceiling, and escapes through the mouth when the draft allows. An inward gust can hold smoke under the rock. Rain splashes and rings mark exposed ground and fuel, and wet ground darkens as it takes rain.

A round log placed off-center on a parallel support can roll to a lower rest. Pieces fall when a support gives way and settle against neighboring fuel. Crossed rails and braced pieces can stay supported by their contacts. Movement advances with hearth time.

Blue drops show rain reaching the viewpoint, and blue marks on the figure linger briefly as you move under cover. Shivering and pale breath show the felt chill from local air temperature, wind and rain. Radiant heat eases the chill. Pale wisps still show drafts around the actual hearth. Set a log across the incoming wind to shelter low coals on its downwind side. Air can still pass above the log and around its ends. A gentle breath can bring out red as oxidation increases. A hard gust can cool the bed.

### Phase 2.1 implementation notes

Gathering trips carry at most 18 pieces or 3.25 kg of dry wood. The selected source supplies the actual species and fuel forms, and the journey can change their moisture. Water content and current weather still affect the delivered pieces after they reach the pile.

Stacking uses the workbench's existing geometric support and gravity solver. Removing or losing a support can reseat a piece or let it fall. The solver approximates weight and contact at each rest. Cold, distant wood samples its local rain and air temperature once per simulated second. Nearby heat brings the same piece into the fixed-step combustion network. Stable distant poses and their render meshes are reused between changes.

In a headless timing fixture with one banked bed, 1,080 simulated seconds took a median of 0.17 seconds with no stock, 0.42 seconds with the opening stock, and 4.57 seconds with 63 pieces. The large pile was deliberately stacked densely. Burning stock and shifting stacks require more work than a cold, stationary pile.

The [Torch Bearer portrait](hearth/torch_bearer.png) is a transparent ImageGen illustration using the original Fire Speaker art as the direct reference. The generation prompt is recorded in [TORCH_BEARER_ART.md](TORCH_BEARER_ART.md).

| Fuel group | Materials and shortcuts |
| --- | --- |
| Tinder | Bark fibres **5**, dry grass **6** |
| Starter | Birch bark **1**, pine twigs **2** |
| Small | Dry splinters **7**, finger sticks **8** |
| Medium | Split branch **9**, pine branch **U**, birch branch **J**, willow branch **K** |
| Large | Thick branch **0**, split oak **3**, long split **-** |
| Waterlogged | Wet oak **4** |

## Heat at hand and Ask the Fire Speaker

Hover over tinder, wood, charcoal, or ash to read it with the hand. Its pale cold outline fills with ochre and orange, then yellow and warm white as heat increases. It combines the contacted surface’s warmth with heat reaching the hand from the fire. Distance, ash, and intervening wood affect that radiant warmth. The reading rises to the working height of a placement preview, and **I** records the tactile description with the inspection.

Ash and spent charcoal can stay hot after the last flame goes out. The hand names hot ash or charcoal on contact, and the Speaker checks separately for enough living red to kindle fresh fuel.

| Moisture cue | What it means |
| --- | --- |
| Ochre or pale hand with no blue | A dry fuel surface, or no material within reach to read |
| Faint slate-blue mark at the wrist | Damp to the touch |
| Clear blue outline | Wet on the surface |
| Deep indigo rim edged in blue | A soaked surface. “Soaked through” also takes the interior into account when the wood has layers |
| Blue marks in the palm | The wood underneath holds more water than the face under your hand |

Heat and moisture fade independently. A warm yellow hand can still have a wet blue outline. Move the cursor along a branch or turn it to compare faces. A warm dry face with a wet heart can still need time at the edge. The hand uses the water, temperature, and evaporation of the touched region. Loose ash stores only mass, so the hand reads its exposure to nearby warmth, rain, or seepage. Ash covering coals shares the coal patch’s water reading.

Press **G** or click **Ask Speaker** during a practice or experiment. A compact question popup opens below the elder without moving his seat. Choose from three contextual suggestions in the dropdown, or type your own question below it. The fuel bar makes room when needed and returns to its usual position when you close the popup. His reply appears in the usual bubble, and **H** opens the history with both your question and the reply. Asking can be done while paused and does not count as tending for apprenticeship progress.

Typed questions combine a small local neural network with subject recognition and the previous exchange. Try **“How do I keep the fire alive?”** or **“What happened to your legs?”**. Follow up with **“Why?”**, **“Show me”**, **“What happens if I don't?”**, or **“Did that help?”**. The Speaker explains his last recommendation or compares the live hearth with what he saw before you tended it. You can also ask **“What should I do next?”** or recall **“What did you tell me before?”**. The whole conversation runs offline in Godot.

The Phase 1.8 model has 27 topics, 624 training examples, and a separate development/evaluation pipeline. On 106 unseen evaluation questions it reached 88.7% top-choice accuracy, with uncertainty rejection and remaining confusions documented in [SPEAKER_NEURAL.md](SPEAKER_NEURAL.md). That guide covers the network, training, model files, Godot inference, bounded memory, character knowledge, future remembered teachings, deployment, CPU measurements and adding content. No death or spiritual presence is implemented in this phase.

| What you might see | Example question | Example reply |
| --- | --- | --- |
| A live coal in One Ember | “Can this ember wake a flame?” | “There is still a little life in the glow. Put a few dry fibres close, with room for a gentle breath.” |
| Pale vapor from wet wood | “Why is it smoking?” | “Some of that pale trail is water from the wood. Set the damp piece in the warmth at the edge.” |
| A bed kept under ash | “Can I bring the flame back?” | “There is warmth beneath the ash. Brush it back, then offer a little dry bark where the red shows.” |
| A cold split laid on a small ember | “Have I laid on too much wood?” | “You have laid cold wood over too little heat. Lift some away and wake the smaller wood first.” |

The Speaker understands fire growth, weak flames, coal strength, overloading, airflow, overcrowding, smoke, moisture, ember viability, hottest location, structure, fuel sizing, banking, relighting, placement, carrying embers, and feeding through openings. Authored answers use current readings and the selected fuel where relevant. Spontaneous observations still appear during ordinary tending.

The hand shows relative warmth at one working point. Shade and hottest-side advice use approximate wood profiles and a small set of likely warm locations. Freeform questions work best as short English questions about one topic. The matcher tolerates common typos and gives an in-world fallback when it cannot place a question.

## Nursing embers and feeding the inner fire

The elder's injured leg keeps him seated. You take over tending the community's fire while he watches and teaches.

- **Keeping A · Nurse a faint ember** starts paused with 13.5 g of viable charcoal at 490 °C. Use **B** to aim at it. Hold for a measured breath, release, advance time, and let it rest between breaths. A gentle breath can help it brighten. Shift-breath can cool and displace it.
- **Keeping B · Carry the ember** starts paused with a faint ember beside prepared dry fibres. Use **C** to drag that same coal into the nest. Release to deposit it, then use gentle breaths. The ember keeps its mass, water, charcoal and thermal history throughout the move.
- **Keeping C · Feed the inner fire** starts an established cabin arrangement. Use **X**, select finger sticks **8**, and work from an open side. Aim the leading tip, adjust its height with **Ctrl+E**, then feed with the wheel or **Up**. The gold dot marks the leading end. A red preview marks a blocked path. After committing, **Down** or the wheel withdraws the selected stick.

Small charcoal keeps a larger local share of its oxidation heat while its surface is relatively cool and has little cold backing. That heat comes from consumed carbon. Directed airflow changes oxygen delivery, oxidation and heat loss. Strong jets can displace a fragile coal. Nearby charcoal exchanges heat through the existing balanced network.

Feeding uses a swept path through the existing fuel geometry, including height, yaw and tilt. It checks the final rest as well as the path, so a clear destination on the far side of a solid log is insufficient. Inserted small sticks gain axial thermal regions. Converting an existing stick preserves its material and sensible heat. The inserted end can then dry and burn ahead of its exposed tail.

In the headless trials, the faint ember ended at **609 °C** after 24 s of timed gentle breaths, compared with **209 °C** untouched and **12 °C** under hard gusts. Moving an 18 g ember at 490 °C into five loose fibre parcels produced local smolder and a **64 kW** flame peak. The tightly packed comparison remained unlit. After four seconds in the feeding trial, the inner end reached about **222 °C**, while the exposed end was about **166 °C**, and ignition began at the inner end.

The collision envelope approximates the visible wood with local cross-sections. Released sticks settle onto supports under gravity. The model uses a bounded path search, a fixed thermal step and reduced visual work during fast-forward.

## Phase 1.5 grain and structural trials

- **Grain A · A log burns from one end** starts a large split over the hot side of the hearth. Advance to about 15 seconds to see the hot end burn beside an intact far end. By about 40 seconds the char front has moved along the log and its hot end is visibly thinner. Use **T** and click to roll it. The hot face, cooler face, and inner layers keep their individual histories.
- **Grain B · A cabin settles** starts with loaded lower rails. Watch the upper course descend as the contact sections thin, then fall or move sideways when support fails.
- **Grain C · A log burns in two** starts with a charred bridge above a bed of coals. The middle gives way at around 1 minute 17 seconds, and the two halves drop and settle. The grain trials open paused. Use **Space** to run them or **+2 seconds** to step through the break.
- **Shift+F3** overlays skin, inner and core temperatures, water and integrity. For a selected piece, **F3** also shows the individual heat ledgers, grain tilt and contact load in newtons.

### How wood changes

Tinder and sticks use one thermal node. Branches and logs retain up to four axial slices. Large detailed pieces have an upper and lower face, two subsurface grain lanes and a core in each slice. Each cell holds its own temperature, timber and water. Exposed cells can also make gas, char and ash. A twisting grain field biases axial, radial and circumferential conduction. As a surface recedes it exposes the next layer, carrying its mass and sensible heat with it. Hot subsurface water can vent through the opened grain. The exposed faces still participate in the Phase 1.4 radiation, plume and conduction network.

Oak, pine, birch, willow and grass are separate material profiles. Fuel forms determine volume, initial water and exposed geometry. Dry mass is volume times density. The profiles also set specific heat, conductance direction, drying, char yield and oxidation, strength and crumbling. The coefficients are representative and tuned for the hearth scale. [USDA Wood Handbook, moisture and physical properties](https://research.fs.usda.gov/treesearch/62243), [mechanical properties](https://research.fs.usda.gov/treesearch/62244)

The support solver uses each slice's crown, underside, integrity and supported weight. A weak section can break under load, or burn through even at floor level. The surviving pieces keep their heat, moisture and fuel. Unsupported fragments accelerate under gravity until they reach a new rest. Large charcoal drops into the bed and small debris aggregates locally. The fixed-step model owns settling, breakage and deposition.

Each intact piece has a continuous wood surface whose profile follows local wear. End grain is exposed at the tips and new breaks have recessed, irregular faces. Fractures still occur between thermal regions, with a bounded search for supports and a cap on the number of fragments.

Larger fuel converts more slowly as its char layer develops. The [burn-time audit](BURN_AUDIT.md) lists measurements for all 14 fuel types and three ember and coal-bed cases, with published comparisons.

### Measured behavior

At 15 simulated seconds in Grain A, the exposed end is burning while the far end retains over 98% of its dry wood. The char front advances into the middle by 40 seconds. In Grain B, the upper course descends from about **0.291 m to 0.267 m** by 40 seconds while it still contains combustible wood. A damaged rail can carry a stick but crush under a heavy split.

The Phase 1.4 gap trial still separates a heated oak from its cold control. With the extra internal grain layers, its hottest face reached **288 °C** and its brief flame peaked at **1.7 kW**. The branch over the deeper bed still ignited at **2.50 s**.

The three new branches have equal dimensions. With their default water loads on the same deep bed, pine, birch and willow decomposed 40.1 g, 17.4 g and 25.0 g respectively after 14 seconds. They lost 13.5 g, 19.6 g and 22.7 g of water.

Small profile changes share contact rebuilds, while actual support failure and breakage update immediately. At high simulation speeds the 3D viewport refreshes less often and uses fewer pixels. Picking and the fixed-step heat model still use the current geometry.

Five-second GTX 1070 Ti samples at 1280×820 began in the burning cabin at 21 simulated seconds. The structure continued to evolve during each sample.

| Speed setting | Average application FPS | Simulated seconds per wall-clock second |
| --- | --- | --- |
| 1× | 57.8 | 1.02 |
| 16× | 21.4 | 8.75 |
| 64× | 21.5 | 14.97 |

The accelerated settings are targets. The dense cabin ran below them. The synthetic benchmark logged transient GLES material warnings after advancing the scene before its first draw. The rendered play checks completed.

## One Ember

1. Place **bark fibres [5]** or **dry grass [6]** close to the glowing coal. Leave small openings between tufts. Stay paused while arranging fuel, then use **+2 seconds** or resume. Watch the first fibres glow before flame spreads.
2. As the fine fuel catches, lay **dry splinters [7]** with their tips near the flame and room between them. For a first build, try two pointing in from opposite sides. A gentle breath can help a prepared spot, while a hard gust or too much cold fuel can cool it.
3. Once splinters are burning, put **finger sticks [8]** against the expanding fire. Add a **split branch [9]** and then thicker fuel as the flame and bed grow. If the little flame fades, inspect the glow before adding weight.
4. Compare with **3D · Tinder nest**, which starts with loose fine fuel and two splinters. For a failure comparison, start One Ember again and place a cold oak split directly on the coal. Use **H → Retry this practice** for a fresh coal.

The fifth practice looks for sustained flame in larger fuel and a growing bed of glowing charcoal. The Speaker can comment on smouldering fibres in a loose nest, the first flame, a cooling coal under heavy fuel, or an open path through the wood.

## Refuel a coal bed

Start with dry splinters or pine twigs over the red coals and leave gaps between pieces. Once you have a standing flame, set one branch or split beside it and wait for that piece to catch before adding more. Several cold splits laid directly over the bed at once can cool it. A dense load can also stop the flame while the coals are still hot. If the bed is still red, move some wood away from the centre and try a small piece. Press **I** to read the bed and look for red coals, smoke between the pieces, or steam from wet wood.

Glowing charcoal now passes a bounded share of its reaction heat to nearby fuel, including across small gaps. In the 3D Healthy Coals trial, three spaced bundles of pine twigs caught from the bed. The same three stacked directly over each other stayed unlit.

## Phase 1.4 heat experiments

Choose the **Heat** comparisons in **Test hearths**. They open paused in 3D. Use **+2 seconds** for close comparisons or **Space** to watch the fire develop. Select a piece before opening **F3** to inspect its regions, or hover over a charcoal patch. **Shift+F3** shows nearby surface temperatures and incoming radiant power in the workbench.

| Trials | Compare |
| --- | --- |
| A1 and A2 | The same bark fibres over a 12.5 g ember and a 115 g charcoal chunk |
| B1 and B2 | The same raised branch over six small coals and six larger patches |
| C1 and C2 | A suspended oak split over the same bed and supports, hot versus cold |
| D1 and D2 | The same six branches in an open or tightly spaced cabin |
| E | A fresh oak split beside an established flame |
| F | A saturated oak load placed on a weak bed |

### Why the old hearths stalled

The warmth index described what the player felt. Actual fuel heating relied on solid links, a flame plume, and a bounded share of active charcoal oxidation. The old cooling term treated surface emission as loss to the surroundings. In some raised setups the heavy support logs also drew heat through an overly broad coal contact, draining the bed before the raised fuel dried and charred.

### What changed

- The solver budgets temperature-driven surface emission and flame radiation separately from hot-gas heating. It uses absolute temperatures to the fourth power, approximate emissivity and exposed area, then distributes energy through cached distance, facing and obstruction weights. A source pays for emission once. Intercepted energy heats the receiving surface and the remainder goes to the surroundings. The cursor's warmth index remains a separate perceptual reading. [NIST solid-phase heat transfer reference](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.1018e6.pdf)
- Coal contact beneath layered wood is limited by the small contact area. Hot charcoal sends a stronger upward plume to exposed undersides, while adjacent coal patches shelter one another from ambient convection. The geometry and local packing decide how much heat and oxygen each surface receives.
- Charcoal keeps mass, effective particle density, porosity, moisture, ash and sensible heat. Thick wood retains more coherent char and sheds larger residues as it burns down. Mixing uses material volumes and heat capacities. Splitting partitions the source material and sensible heat.
- Exposed surfaces dry and decompose as they heat. The gas reaction depends on accumulated volatiles, oxygen, wet-fuel dilution and the local gas temperature estimate. Hot plume input can pilot gas above a heated surface. Flame and charcoal feedback are limited shares of reaction power derived from material consumption. [USDA Wood Handbook on wood ignition and charring](https://research.fs.usda.gov/treesearch/62268)

Radiation is a lumped, grey-surface approximation using nearby links and a midpoint obstruction sample. It shares the calibrated environmental cooling envelope. Draft and plume capture are empirical and oxygen combines a shared supply with local shelter and packing. Surface temperature is capped at 1160 °C. Escaping gases, ash and moving air use aggregate loss terms. These readings compare arrangements within Firetender.

### Before and after

These measurements use 140 simulated seconds and count first flame when the target exceeds 2 kW. Peak temperatures are for the hottest target surface. The seed coal temperatures in the matched comparisons stayed the same.

| Comparison | Previous model | Phase 1.4 |
| --- | --- | --- |
| A · Ember and chunk | Tinder lit at 2.50 and 1.50 s. Bed glow lasted 15.0 s and at least 140 s. | Tinder lit at 2.50 and 1.25 s. Bed glow lasted 15.5 s and at least 140 s. An equal-temperature check also separates the chunk and ember. |
| B · Small and deep beds | The raised branches peaked at 34 and 137 °C. Both stayed dark. | Small bed peaked at 38 °C and stayed dark. Deep bed lit the branch at 2.50 s and decomposed about 138 g of it by 30 s. |
| C · Hot and cold gap | Oak peaked at 116 °C over hot coals and 12 °C over cold coals. | Hot-bed oak peaked at 293 °C and produced a brief 2.4 kW flame. It absorbed 111 kJ of radiation and 290 kJ from plumes over the run. Cold control remained at 12 °C. |
| D · Open and tight cabin | Upper pieces peaked at 113 and 157 °C. Both stayed dark. | An open upper piece lit at 13.50 s. Its matched tight counterpart peaked at 176 °C and stayed dark. Early oxygen was 70% and 34% of fresh air, respectively. |
| E · Established fire | Fresh split lit at 2.50 s and peaked at 67.4 kW. | Fresh split lit at 13.00 s and peaked at 67.9 kW. The hearth produced 6.39 MJ of flame energy over the run. |
| F · Wet load | Wet oak stayed dark, with a peak surface temperature of 87 °C. | Wet oak stayed dark, with a peak of 62 °C. The weak bed stopped visibly glowing after 6.5 s. |

Healthy Coals lit fresh pine at 3.25 s versus 3.75 s before. Uncovered Banked Coals did so at 1.75 s versus 2.00 s. Dying Embers stayed dark in both runs. The original cabin and cone demonstrations now use fuller beds and physically simulated warm-up before the upper pieces are seated. The cabin's upper course lit at 17.75 s. The revised cone sustained flame in the structure, while its last splinter stayed below 2 kW. Lean-to and Parallel Rails were also exercised. The suspended oak produces a brief flame in this specific gap experiment, while the smaller raised branch sustains a larger fire.

The conservation suite reconciles absorbed and emitted radiant power and checks the per-source capture limit, symmetric solid conduction, gas and charcoal consumption, and heat and material volume after splitting. It also compares quarter- and eighth-second ignition runs. The regular game runs at quarter-second steps.

## Tinder heat transfer

The previous model already gave bark fibres and dry grass small dry masses of 3.2 g and 4.2 g. Heat moved in equal and opposite amounts across each contact, but each parcel could draw from the same small coal surface. Adding parcels also added exposed cooling surfaces. There was little thermal benefit from neighbouring fibres, and the model relied on hot gas and charcoal reactions to return heat after ignition. With five loose parcels, the coal and tinder cooled before any flame took hold.

The updated model limits aggregate coal-to-fibre conductance and distributes it by thermal capacity and contact geometry. Nearby fibre mass shelters the hot region from environmental cooling. Packing across the path of rising air separately restricts the oxygen available to the coal and fibres. Warm, dry fibres can oxidise in place, consume fuel and oxygen, produce smoke and residual char, and pass part of their heat to nearby fuel. The model retains the 12.5 g, 770 °C starting coal and its existing charcoal reaction rate. It uses effective porous parcels with lumped temperatures. Particle size, oxygen and packing are separate factors in laboratory studies of smouldering beds. [Qin et al.](https://ira.lib.polyu.edu.hk/handle/10397/108030)

The Phase 1.3.1 benchmark uses the same One Ember start and reports model values, with the first flame above 2 kW measured over 40 simulated seconds. The coal temperature and warmest tinder temperature are sampled at 3 seconds.

| Arrangement | Coal / fuel °C, before → after | First flame, before → after | Flame energy, before → after |
| --- | --- | --- | --- |
| One dry parcel | 514 / 401 → 529 / 416 | 2.50 → 2.50 s | 37.2 → 31.5 kJ |
| Two dry parcels | 479 / 190 → 561 / 212 | None → 7.50 s | 0 → 46.9 kJ |
| Five loose, 16 g | 433 / 148 → 611 / 192 | None → 6.25 s | 0 → 168.3 kJ |
| Ten airy, 32 g | 410 / 123 → 616 / 161 | None → 12.50 s | 0 → 328.5 kJ |
| Five compact | 342 / 253 → 425 / 303 | None → 7.25 s | 0 → 150.1 kJ |
| Ten tightly packed | After 374 / 255 | None after | 0 kJ after |
| One effective porous bundle, 16 g | After 402 / 210 | 5.00 s after | 151.1 kJ after |
| Coarse wood, 16 g | 262 / 210 → 262 / 210 | None in either run | 0 kJ in both runs |
| One soaked parcel | 247 / 145 → 294 / 131 | None in either run | 0 kJ in both runs |

The five loose parcels lost 3.09 kJ of coal sensible heat at 3 seconds, compared with 4.50 kJ beside the single dry parcel. Three of the five separate parcels began smouldering before visible flame. The lumped bundle has a wider footprint centred over the coal and draws heat faster initially than the ring, yet both arrangements establish flame. In Phase 1.4, splitting the five parcels in half at identical thermal footprints changes the first second's coal temperature by less than 0.01 °C. Five soaked parcels and ten tightly packed dry parcels both failed to establish flame.

## Structure demonstrations

Use **Experiment** to load the new demonstrations or the original trials.

- **3D · Log cabin** has three courses. Orbit low, then pull a bottom rail out or move a top rail to the floor. To build your own, place two parallel rails with a gap, then turn the next two across them so each touches both.
- **3D · Lean-to** has a raised edge and low ends. Remove the prop and observe how the branches settle.
- **3D · Cone** gathers tilted pieces around a central rest. Inspect its different contact points from several angles.
- **3D · Parallel rails** leaves a central opening. Compare heating and residue with the cabin.
- **3D · Tinder nest** shows the gap between the fine material and the next fuel size.
- **G · A wet end over flame** compares two ends of a supported log. Inspect it after about 17 simulated seconds, then lower or roll it and inspect again.
- **A–F** retain the original local coal, rolling, breath, wet-fuel, banking, and extinction experiments.

## Model and performance

Combustion still advances in deterministic 0.25-second steps. The workbench ray-picks real fuel axes. The support solver samples the ground and adds intersection samples at nearby rails, then seats the piece against the best supported lean. Precise fuel gradually loses bearing radius as material burns, then settles the pieces above it when it can no longer carry them. Each fuel has up to four thermal regions. Larger regions have independent surfaces and a core, with heat moving between adjacent regions. Solid conduction falls away across a gap, while rising and wind-driven combustion can still carry heat through it.

The workbench reads the `Fire` model. Combustion, grain wear, support failure and charcoal deposition run in the fixed-step model and can run headlessly. At normal speed the Compatibility viewport uses the full canvas resolution. At 16×, 64×, and during long time jumps it uses a smaller render target, skips intermediate draws and omits short-lived decorative falling-coal bodies. The model still calculates each fall and deposit, and the camera and ray picker use the current scene coordinates.

For the Phase 1.5.1 comparison, the old 3D workbench and the unified hearth ran five-second samples at 1280×820 on a GTX 1070 Ti. Each sample started from the same prepared Grain B cabin, warmed to 21 simulated seconds before playback. The new build was sampled twice.

| Speed setting | Application FPS before → after | Simulated seconds per real second before → after |
| --- | --- | --- |
| 1× | 57.8 → 58.0 | 1.00 → 1.00 |
| 16× | 26.3 → 38.8–40.3 | 9.83 → 13.99–14.32 |
| 64× | 26.5 → 39.8–40.0 | 23.24 → 32.85–33.42 |

These short samples measure one evolving arrangement. Both builds logged transient OpenGL material warnings during the synthetic warm-up.

Log settling uses sampled contacts, section wear, and bounded gravity-driven shifts. Heat, ventilation, and moisture use lumped approximations. A drag is a placement preview until release. Large dense structures can run below the requested accelerated speed.

## Verify

Use a Godot console executable from the project directory.

```powershell
godot --headless --path . --script tests/physical_work_checks.gd
godot --headless --path . --script tests/physical_work_scene_checks.gd
godot --headless --path . --script tests/mind_cave_checks.gd
godot --headless --path . --script tests/mind_cave_scene_checks.gd
godot --headless --path . --script tests/family_checks.gd
godot --headless --path . --script tests/family_scene_checks.gd
godot --headless --path . --script tests/fire_checks.gd
godot --headless --path . --script tests/apprentice_checks.gd
godot --headless --path . --script tests/construction_checks.gd
godot --headless --path . --script tests/tinder_checks.gd
godot --headless --path . --script tests/thermal_checks.gd
godot --headless --path . --script tests/grain_checks.gd
godot --headless --path . --script tests/advice_checks.gd
godot --headless --path . --script tests/touch_checks.gd
godot --headless --path . --script tests/hearth_feedback_checks.gd
godot --headless --path . --script tests/ambient_weather_checks.gd
godot --headless --path . --script tests/cave_draft_checks.gd
godot --headless --path . --script tests/weather_physics_checks.gd
godot --headless --path . --script tests/keeping_checks.gd
godot --headless --path . --script tests/neural_checks.gd
godot --headless --path . --script tests/conversation_checks.gd
godot --headless --path . --script tests/red_hollow_checks.gd
godot --headless --path . --script tests/after_storm_checks.gd
godot --headless --path . --script tests/woodpile_checks.gd
godot --headless --path . --script tests/preparedness_checks.gd
godot --path . --resolution 1280x820 --script tests/red_hollow_scene_checks.gd
godot --path . --resolution 1280x820 --script tests/red_hollow_continuity_checks.gd
godot --path . --resolution 1280x820 --script tests/after_storm_scene_checks.gd
godot --path . --resolution 1280x820 --script tests/valley_scene_checks.gd
godot --path . --resolution 1280x820 --script tests/scene_checks.gd
godot --path . --resolution 1280x820 --script tests/touch_checks.gd
godot --path . --resolution 1280x820 --script tests/hearth_feedback_checks.gd
godot --path . --resolution 1280x820 --script tests/ambient_weather_checks.gd
godot --path . --resolution 1280x820 --script tests/cave_draft_checks.gd
godot --path . --resolution 1280x820 --script tests/weather_physics_checks.gd
godot --path . --resolution 1280x820 --script tests/red_hollow_journey_checks.gd
godot --path . --resolution 1280x820 --script tests/workbench_checks.gd
```

Pass an existing directory after `--` to a rendered suite to capture review frames.

Chapter II checks cover the live handoff, offline tale, physical storage, moisture and heat accounting, steam pops, resin consumption, ember trajectories and ignition, and a repeatable successful tending course. The enhanced drying and spark behavior is exercised through Chapter II. The original experiments retain their established calibration.

The spatial continuity suite exercises all three hearth sites. It checks Chapter I storage placement, compares the same rendered scenery instances and transforms across the handoff, and verifies that inherited fuel keeps its physical rest. It can capture both chapters from the same two camera transforms.

The full journey starts with the rescued ember, stocks dry fuel and banks through the storm. It continues through both methods of drying wet logs while keeping the inherited fire alive, then checks the Chapter II results and Chapter III loading page.

In the matched 80-second drying fixture, birch beside radiant heat lost 14.3 g of water, birch in the air passage lost 2.0 g, and birch at the seep gained 14.2 g. The contact fixture ignited exposed dry tinder, while soaked and separated tinder stayed dark. Two replays of the developer chapter prepared a 269 g reserve of seasoned wood and retained 203 g of hot charcoal in 134.25 simulated seconds.

Phase 2.2.3 checks cover full rotation, rear-wall occlusion, and the corner layout at 1152×738, 1280×820, 1600×900, and 1920×1016. A separate 72-pose sweep at maximum zoom checked all three hearth sites and found no exposed viewport background. The exported build passed the full-turn scene checks, and the three-day story replay retained its previous result.

Phase 2.2.2 passed **636 standard checks across 17 suites**. The updated scene checks verify that all four panels join at their edges, remain fixed relative to the cliff during orbit, and show the nearer slope separately from the distant ridges. They also check that the limestone and the underside of the shelf occlude the artwork at the zoom and orbit limits. Visual checks passed at 1152×738, 1280×820, and 1600×900. The three-day chapter replay retained its previous fire and weather results.

Phase 2.2.1 passed **629 standard checks across 17 suites**. The valley scene suite verifies rock occlusion, firelight, weather, maximum zoom and low orbits at 1152×738, 1280×820, and 1600×900. The rendered workbench suite also covers fuel picking and placement, experimental hearths, and the reduced viewport refresh cadence during fast-forward. The review captures include a staged night fire for comparing interior light and an approaching front viewed from under the roof.

Phase 2.2 passed **625 standard checks across 17 suites**, plus optional captures. The weather scene checks cover 1152×738, 1280×820, and 1600×900. They probe for exposed background at maximum zoom and low orbit, and verify the moon, dusk color, distant rain, local drops, smoke, and the lower-left layout. The packed build also passed the chapter, preparedness, and valley checks in an empty project directory. The deterministic three-day replay retained the Phase 2.1 result of 227 g of charcoal and a hottest coal at 688 °C.

An uncapped paused-storm fixture at 1280×820 on the GTX 1070 Ti measured a median of 256 FPS in Phase 2.1 and 275 FPS in Phase 2.2, across three short samples per build. This measures the outlook rendering workload. Accelerated simulation still uses the existing reduced refresh cadence and fixed quarter-second physics steps.

Phase 2.1 passed **586 standard checks across 15 suites**, plus the optional image captures. The clan wood tests cover storage transfers, stacking and falling, rain and heat exposure, finite sites, daylight, the two recommendations, and the handoff. The chapter completed the same deterministic three-day schedule with 227 g of charcoal and a hottest coal at 688 °C. The exported data pack passed the woodpile, three-day chapter, and rendered chapter suites without the source project. The rendered checks cover the new portrait, direct picking, and the stationary Fire Speaker dialogue.

Phase 2 passed **554 standard checks across fourteen suites**, plus three chapter capture checks. The chapter tests cover the normal launch, replay, the scout’s finite routes, actual stock use, ash conservation, rain penetration, kinship dialogue and both a cold-hearth ending and a successful run. Two identical tending schedules finished all three story days with identical results at 1,080 simulated seconds. The successful hearth held 227 g of charcoal with the hottest coal at 688 °C. Those are developer readings from the test, not dialogue or story requirements. The Windows data pack passed the chapter’s headless and rendered checks with its local assets and model. The original two-hour deterministic run and all 37 experimental hearths also passed.

Phase 1.4 validation on Godot 4.7.2 passed 265 checks across seven suites. The totals were 46 combustion, 34 apprenticeship, 24 construction, 23 tinder, 31 thermal, 48 rendered scene, and 59 rendered workbench checks. The combustion suite ran both deterministic two-hour simulations to completion. The growth checks measure sustained branch flame over time alongside the final coal reserve.

Phase 1.5 validation on the same engine passed **304 checks across eight suites**. The totals were 46 combustion, 34 apprenticeship, 24 construction, 23 tinder, 31 thermal, 28 grain, 48 rendered scene, and 70 rendered workbench checks. The two-hour combustion stress case stayed bounded and deterministic.

Phase 1.5.1 passed **344 checks across all eight suites**. The 54 rendered scene checks exercise the opening through banking and the first One Ember flame. The 104 rendered workbench checks load all 33 experiments in sequence, compare each starting state with its headless model, and compare an accelerated time jump with the equivalent fixed steps. The six headless suites include the deterministic two-hour run and the complete One Ember apprenticeship.

The WASD, burn-rate, and fracture update passed **375 checks across all eight suites**, including 18 optional capture checks. The workbench suite verifies camera-relative movement, the skin across worn grain regions, the exposed break surfaces, and the falling halves in Grain C.

Phase 1.6 passed **417 checks across nine suites**, including the two-hour deterministic run. The rendered scene suite also passed at 1152×738, 1280×820, and 1600×900. The new checks cover distance and wood shielding, preview height, prompt selection, rough questions, advice from live cues, and the relationship between consultation and the existing Speaker queue.

Phase 1.7 passed **450 standard checks across ten suites**, plus the optional capture checks. The rendered interface passed at 1152×738, 1280×820, and 1600×900. Tests exercise timed breaths, exhausted charcoal, material and heat conservation during ember carrying, loose and packed nests, swept insertion and withdrawal, rotation against an obstacle, and picking a fed stick from a low camera angle. The existing two-hour deterministic combustion run also completed.

Phase 1.8 passed **479 standard checks across eleven suites**, plus fourteen capture checks. The neural suite compares every Python/Godot evaluation prediction and checks grounding, follow-ups, character consistency, bounded teaching memory, deterministic combustion and CPU allocation. All existing suites passed, including the two-hour deterministic comparison and all 37 experimental hearths. Typed neural replies fit the stationary Speaker layout at 1152×738, 1280×820 and 1600×900. The exported data pack also passes the separate runtime-only Speaker checks without Python or training data.

The community of fifteen and its reliance on inherited fire are story choices for this hearth. Research into Neanderthal hearing and speech capacity and evidence of fire-making among some Neanderthal groups informed the portrayal. [Conde-Valverde et al.](https://www.nature.com/articles/s41559-021-01391-6), [Sorensen et al.](https://www.nature.com/articles/s41598-018-28342-9)
