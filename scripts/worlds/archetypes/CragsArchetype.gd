class_name CragsArchetype
extends GardenArchetype
## The crags: the first band up from the garden (docs/REGIONS_PLAN.md §7), cliffs with castle
## ruins. For now a stand-in until its own sample, structures and decor are drawn: the garden's
## tunnels and dressing, printed in the sky's realm so it reads as a different place.


func _init() -> void:
	super()
	name = &"crags"


func realm() -> StringName:
	return &"sky"
