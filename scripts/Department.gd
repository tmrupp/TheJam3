extends Area2D
class_name Department
## A department's portal, standing at the lectern end of an institute lecture hall (Institute): each
## department studies a region (Institute.DEPARTMENTS: botany the garden, necrology the cemetery,
## geology the crags, astronomy the sky) and its portal leads to a real level there, in the same
## world column (docs/REGIONS_PLAN.md §7), at a row of the band dealt with the level
## (Institute.department_row). Where it leads is printed over it, the place's marks and numbers,
## before the wizard steps through (DepartmentArt). Through it, the wizard comes out at that level's
## way back, where a way back opens (WayBack), lasting until they use it (MapInfo.department_travel,
## RunState.way_back). It pays no heed to seals: it reaches past a living boss's gate (the exception
## to "nothing skips a seal", docs/REGIONS_PLAN.md §4). A way back left open elsewhere closes when
## another department portal is used.

var map_info: MapInfo
## Its cell, its department, and the row it leads to.
var cell: Vector2i = Vector2i(-1, -1)
var dept: StringName = &""
var row: int = 0


func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	map_info = info
	cell = v
	if extra is Array and (extra as Array).size() == 2:
		dept = StringName(extra[0])
		row = int(extra[1])


## Where it leads: the level at its row, in this world.
func destination() -> Vector2i:
	var x: int = map_info.coord.x if map_info != null else 0
	return Vector2i(x, row)


## The band it leads into (the archetype its department studies).
func band() -> StringName:
	return Institute.DEPARTMENTS.get(dept, &"garden")


func use() -> void:
	if map_info == null or map_info.travelling or map_info.run_ending > 0.0:
		return
	map_info.department_travel(destination(), cell)


func _ready() -> void:
	$Interactable.interacted.connect(use)
	# It glows (RisoLight).
	add_to_group(RisoLight.GLOWS)
