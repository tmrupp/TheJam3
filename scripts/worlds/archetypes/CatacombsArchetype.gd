class_name CatacombsArchetype
extends CemeteryArchetype
## The catacombs: the band below the cemetery (docs/REGIONS_PLAN.md §7), tight tunnels and burial
## chambers in the dark. For now a stand-in until its own sample, darkness and decor are made: the
## cemetery's terraces, chasms, moths and wraiths, in the cemetery's realm.


func _init() -> void:
	super()
	name = &"catacombs"


func realm() -> StringName:
	return &"cemetery"
