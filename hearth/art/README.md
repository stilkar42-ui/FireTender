# Red Hollow exterior artwork

Red Hollow uses [red-hollow-panorama.png](red-hollow-panorama.png) and [red-hollow-midground.png](red-hollow-midground.png), made with ImageGen using both character portraits as style references. A single world-space arc holds the distant painting. The foreground has an alpha channel and sits on a nearer arc. The 3D limestone and the two paintings share a perspective camera and the same native Godot sky.

## Author another hearth location

Duplicate [red_hollow.tres](red_hollow.tres) in Godot. Open the copy in the Inspector, replace the following assets, then assign it to **Scenery** on the root of [hearth.tscn](../hearth.tscn).

| Slot | What to make |
| --- | --- |
| **Set Scene** | A `Node3D` scene for nearby geometry such as walls, shelter, trees, and props. Put the hearth at the origin, keep the work surface at Y = 0, and frame the main opening toward +Z. The real geometry supplies occlusion. |
| **Ground Scene** | An optional `Node3D` scene for terrain and vegetation beyond the working floor. Its origin stays at the hearth as the shelter set shifts between hearth sites. |
| **Panorama** | A single wide 3:1 RGB painting of the far landscape. Put the main view at the center and the highest distant ridge roughly 55–60% down from the top. Leave room above it for painted clouds and the blend into the sky. At 360° the left and right edges need to join. |
| **Foreground** | A separate wide RGBA painting of nearer slopes or vegetation. Paint the land and let the air above its outline remain transparent. Keep the center low enough to show the distant scene. |
| **Ground** | An optional Godot material for the shared work surface and ledge. |

Use the Fire Speaker, Torch Bearer, and the Red Hollow paintings as a reference set when generating new art. Ask for muted ochre and slate, angular gouache forms, atmospheric depth, and a restrained foreground silhouette. Generate the distant and nearer paintings separately with the same palette and direction of light. Leave the sun, moon, stars, and rain out of the source images. The shared renderer supplies daylight, the moon, stars, and storm art.

Set **Home Eye**, **Home Target**, **Eye Bounds**, and **Focus Bounds** to fit the set. **Camera Obstacles** are boxes in the set scene’s local space that shorten the orbit at walls or a roof. **Panorama Span** controls how much of the horizon painting wraps around the location. **Exterior Scale** pushes both painted layers beyond deeper 3D terrain. Red Hollow uses a 270° span because the rear is solid rock. Physical shelter exposure and story behavior come from the chapter.

## Phase 2.2.2 prompts

### Panorama master

> Use case: illustration-story. Asset type: very wide panoramic master painting for a prehistoric game, ideally an ultra-wide 3:1 or 4:1 horizontal image. The first two supplied portraits are direct style references for faceted ink and dry gouache, and the third image is a palette and landscape reference. Paint one uninterrupted 270-degree view of a broad deep prehistoric valley in southwestern France, seen from high up inside a limestone shelter. This is the FAR landscape and sky, so all individual trees are tiny marks. Shape the composition for FOUR equal-width adjacent scenic panels with the same horizon and perfectly continuous brush strokes at the quarter boundaries. Far left: a receding pale wooded shoulder. Center-left: cool ridges layered behind an open valley gap. Center-right: distant river winding at the bottom of the valley, with cool slate mountains above it. Far right: broad hazy escarpment and wooded far slopes. Keep the distant mountain crest at roughly 50–58 percent down the canvas, with spacious cool gray-blue parchment sky and restrained soft-edged angular cloud strokes above. The lower half has only DISTANT slopes and haze, no nearby banks, cave rim or large trees. Deliberate broad paint shapes, small angular dark ink accents, limited warm ochre and smoky slate / sage / limestone palette. More atmospheric and lower contrast than the character sprites, but recognizably the same hand. No photorealism, floating props, borders, panels separated by lines, lettering, sun, moon or people. Fill the frame edge to edge.

### Valley midground

> Use case: illustration-story. Asset type: ultra-wide horizontal true-alpha painted foreground/midground cutout for Firetender. The supplied two character portraits set the angular umber-ink and dry gouache style, and the valley painting sets palette. Paint ONE cohesive uneven strip of terrain just below a high prehistoric limestone shelf, seen outward and down into a valley. The low-lying center opens onto a deep drop, with ochre and dark slate rock strata, separated wooded knolls, small gnarled bushes and broken brush marks descending diagonally on either side. Several shadowed folds and overlapping earth tones imply distance from the near lip to the far wooded valley. Draw the actual upper terrain silhouette as an irregular low bowl and preserve transparent air above it. Keep the middle upper opening generous. Artwork should occupy the bottom 45–65 percent, full bleed across the bottom and both sides. Real transparency above the irregular hill edges with clean cutout alpha. No sky, fog background, distant horizon, giant foreground trees, framing cave, flat platform, people or text. Restrained painted shapes, subdued smoky olive, burnt sienna, shale and muted cool haze.

## Phase 2.2.1 artwork

The four PNGs were created with the built-in ImageGen tool using the existing Fire Speaker and Torch Bearer portraits as direct style references. The Fire Speaker reference was rasterized from [the original portrait](../fire_speaker.svg). The alpha channels on the three sky overlays are preserved.

The [valley painting](red-hollow-valley.png) is the base layer. The [storm front and rain](red-hollow-storm.png), [stars and Milky Way](red-hollow-stars.png), and [moon](red-hollow-moon.png) are composited behind the limestone. The chapter clock controls their movement, tint and visibility. The moon painting is shaded in the shader to show phase.

## Generation prompts

### Valley

> Use case: illustration-story. Asset type: wide 3:2 background painting for Firetender. Images 1 and 2 are the direct style references only: match their confident angular silhouettes, dark umber ink edges, sparse dry-brush marks, broad gouache planes, and subtle grain. Show the exterior that a family would look out on from a prehistoric limestone shelter in southwestern France: gently folding wooded ridges, a deep off-center valley, glimmers of water winding very far below, and distinct atmospheric intervals between the ridges. A composed wide landscape with the irregular crest of the far hills roughly 45 percent down the image, hazy broken pale cloud strokes in the top half, and nearer trees and angular dark slopes at the bottom. Main colors muted warm slate-blue, smoky olive, tawny grey, muted parchment light, charcoal umber in the near trees. Distinct hand-drawn oak and pine masses with restrained detail and atmospheric distance. Hand-painted narrative adventure art, controlled dark ink accents and painted light facets, readable shapes at small scale, no photographic effects. Only exterior scenery, filling the frame edge-to-edge, with no cave frame, people, text, sun disc, moon, hard decorative border or foreground objects. The image is the quiet valley through a rock opening, viewed outward from slightly above the valley.

### Storm

> Use case: illustration-story. Asset type: 3:2 transparent RGBA storm overlay for Firetender. Images 1 and 2 are direct style references only: match their angular shape language, muted earth/charcoal inks, restrained brushwork and flat gouache planes. Across the upper half paint a wide leading storm cloud bank made of overlapping angular charcoal slate, blue-grey and warm ash facets, with grey lit underside and an irregular leading edge. A few broad hand-painted dry-brush grey rain veils trail downward from portions of its base, with visible diagonally brushed strokes and gaps between them. Keep cloud forms mostly in the upper 40 percent and rain streaks very lightly tapering between roughly 40 and 72 percent. The bottom quarter and corners must be truly transparent so underlying painted valley is visible. This is a cutout weather layer, no backdrop/sky color, horizon, landscape, text or people. Preserve a clean compositing alpha around the entire silhouette and between cloud and rain shapes. No gradients standing in for shapes, no photography.

### Night

> Use case: illustration-story. Asset type: 3:2 transparent RGBA night-sky overlay for Firetender. The two supplied characters are direct style references only. Paint a very faint broken dusty arc of the Milky Way stretching diagonally across the upper half, small scattered stars rendered as restrained hand-dabbed angular off-white ink flecks and subdued slate blue brush stipple. No bright nebula, no regular spacing, no lens flare. All negative space truly transparent, especially lower half. There is no background, moon, ground, text, frame or person. This is a subtle compositing layer over an illustrated prehistoric sky. Keep the art in a hand-painted storybook ink and gouache style, angular and restrained with generous empty space.

### Moon

> Use case: illustration-story. Asset type: an isolated game moon cutout on true transparent alpha, square. Images 1 and 2 are direct style references only. Paint a single small full circular moon centered and occupying about 88 percent of the image width, in the same angular hand-painted ink and gouache style as the character sprites. Muted warm chalk and limestone color, spare flat grey-brown angular maria and a few dry-brushed facets. Almost round with slight brush irregularities. The full disk must be lit evenly because the game applies its own shadow to show phase. No sky, glow, halo, stars, text, extra objects, frame or characters. Transparent outside the moon. Readable when shown as a 28-pixel disc.

