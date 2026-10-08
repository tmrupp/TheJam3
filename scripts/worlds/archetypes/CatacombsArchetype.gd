class_name CatacombsArchetype
extends CemeteryArchetype
## The catacombs: the band below the cemetery (docs/REGIONS_PLAN.md §7), tight tunnels and burial
## chambers in the dark: deep darkness (`gloom`), so most of what the wizard sees is what their
## lantern lights. For now the rest is a stand-in until its own sample and decor are made: the
## cemetery's terraces, chasms, moths and wraiths, in the cemetery's realm.

## Its darkness: out of sight, and everywhere the lanterns do not light.
const SHADE_DEEP: float = 0.6
const GLOOM: float = 0.6


func _init() -> void:
	super()
	name = &"catacombs"
	shade = SHADE_DEEP
	gloom = GLOOM


func realm() -> StringName:
	return &"cemetery"
