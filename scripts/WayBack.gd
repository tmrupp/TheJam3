extends Area2D
class_name WayBack
## The way back an institute department's portal opens where it leads (Department): a portal
## standing by that level's way back, leading back to the department's portal in the institute.
## It lasts until it is used (RunState.way_back), and is put back each time its level is loaded
## (MapInfo._spawn_way_back). Printed as a department's portal (DepartmentArt), its plaque showing
## the institute it leads back to.

var map_info: MapInfo


func setup(info: MapInfo) -> void:
	map_info = info


## Where it leads: the institute level whose portal opened it.
func destination() -> Vector2i:
	var back: Array = map_info.run.way_back if map_info != null else []
	return back[2] if back.size() >= 4 else Vector2i.ZERO


func use() -> void:
	if map_info == null or map_info.travelling or map_info.run_ending > 0.0:
		return
	map_info.way_back_travel()


func _ready() -> void:
	$Interactable.interacted.connect(use)
	add_to_group(RisoLight.GLOWS)
