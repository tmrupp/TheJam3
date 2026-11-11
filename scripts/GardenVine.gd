class_name GardenVine
extends BrambleVine
## A thorn vine grown out of a garden wall on its own, as a seed pod is a bulb on its own
## (docs/REVIEW_PLAN.md §2.4): one of the bramble's vines (BrambleVine), with no bramble, lashing
## REACH cells out of its wall and pulling back on its steady cadence, hurting only while out, a
## parry recoiling it for the stun. Laid in the garden's levels near the bramble as a sign of it
## (GardenArchetype.place_spares, kept as the run's nearness calls for, Bosses.spare_kept). Printed
## as the bramble prints its vines (VineArt, Bramble.ink_vine).


## Rooted at the face of the wall beside cell `v` (the rock left of it first, else right; else the
## floor under it), its cadence started part way by the level seed and the cell.
func setup(info: MapInfo, v: Vector2i) -> void:
	cell = v
	way = SeedPod.facing(info.world, v)
	var cell_px: float = (info.cell_position(v + Vector2i.RIGHT) - info.cell_position(v)).x
	place(info.cell_position(v) - way * cell_px * 0.5, cell_px, info.world.seed_for_colors)
