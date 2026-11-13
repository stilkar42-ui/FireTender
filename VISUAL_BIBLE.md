# Firetender · Visual Bible

Red Hollow is an illustrated limestone shelter with real depth. The existing Fire Speaker, Torch Bearer and family cutouts set the standard for brushwork, shape and contrast. The camera moves through a continuous 3D space and the art follows the same space as the fire and work.

| Color | Swatch | Use |
| --- | --- | --- |
| Ochre | `#B4814D` | Split wood, dry dirt, painted marks |
| Umber | `#625041` | Bark, hide, soil and reflected shadows |
| Charcoal brown | `#2E2624` | Burned wood, hearth center and deep occlusion |
| Limestone grey | `#857D70` | The cave lip, strata and shelving |
| Muted green | `#646B51` | Exterior vegetation and damp moss |
| Ember orange | `#ED7933` | Living coals, sparks and reflected firelight |
| Ash white | `#BEB2A0` | Cooled residue, stone dust and bone highlights |
| Smoke blue-grey | `#737D86` | Seep, night shadows and distant air |

## Shape and brushwork

Use broad masses, then add a few surface details that explain the material. Limestone carries long sediment strokes with broken ledges and softened edges. Earth carries broad ochre scumbles and a darker, irregular hearth stain. Bark runs along the piece, end grain turns across the cut face, and split faces expose paler wood. Use the piece’s scale and silhouette to identify it before its texture is visible. Keep contrast low in the background and save the strongest accents for the active bed and the objects being handled.

Work surfaces should show how they are used. Give the butcher’s board grain and darker cut marks, the maker’s stone tool scars and resin colors, and the cooking area soot and warmed ochre. Keep thin shafts and spits readable in silhouette. Let raw meat, bone, leather and flint retain their own subdued colors under the same light.

## Light and state

Make all world surfaces matte. Daylight is broad and cool. Firelight falls from the simulated bed onto the closest stones, objects and people. As the bed dims, the cave returns to cool shadows. Preserve the dark hearth stain and soft contact shadows so pieces appear to rest on the ground. Keep cutout depth and character pose anchors.

| State | Visual cue |
| --- | --- |
| Dry | Warm, porous painted surface with clear grain |
| Damp or wet | Cooler, darker washes with a restrained satin accent and visible steam when heated |
| Scorched | Burnt sienna into dark umber, with grain still readable |
| Charred | Broken charcoal values and cracks following the grain |
| Living coal | Concentrated red and amber in the hottest cracks |
| Ash | Pale matte powder, darkest at its mixed charcoal edge |

## Production

Use separate materials for bark, cut faces, stone, soil and organic workshop surfaces. Bind those materials to the existing poses and object state. Give wall and floor art world-space coordinates and use local coordinates for movable items so the paint follows the object. Keep interaction extents, support physics, station targets and the simulation clock in their current systems.

`hearth/painted_material.gd` binds the swatches and supplies the shared light colors to cutouts. The cave and floor shaders project pigment over the visible shell. Log and prop shaders read each object’s existing pose and surface state. The build guide and hearth inspection still use the real placement coordinates. The textures under `hearth/art/painted` use mipmaps for stable strokes when zooming out.

Review the same camera angles before and after the pass. Include the hearth, the mouth, the back shelf and seep, the woodpile, and all three workstations. Check day and night with the same fire geometry and seated family art.

[View the reference sheet and matched gameplay screenshots](outputs/ui-review/painted-world/REVIEW.md)

### ImageGen briefs

The built-in ImageGen tool supplied the style study and two material atlases. The style study used the existing Nara gameplay capture as its reference. The texture atlases were cropped into individual swatches for the Godot materials.

- **Style study.** Paint a full limestone shelter scene with seated family cutouts, then study the wall, floor, hearth, woodpile, a single log, charcoal and ash, cooking, hunting and making. Match the character art with matte gouache, ochre and umber, soft limestone shadows and small amber highlights.
- **First material atlas.** Paint four flat, unlit swatches at equal scale. Use ash-grey sedimentary limestone, compacted ochre earth, longitudinal umber bark and pale cut wood with growth arcs.
- **Second material atlas.** Paint four flat, unlit swatches with dry brush detail. Use ash-stained earthen clay, slate-grey flint, weathered ochre hide and brushed ivory bone.
