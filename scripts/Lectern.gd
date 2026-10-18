extends Area2D
class_name Lectern
## A classroom's lectern (Institute.furnish), printed as a lesson's (LecternArt): a pigeonhole. It
## holds one exam paper (MapInfo.lectern_slot). Interact to put the paper picked up last
## on it and take the one it held, either of which may be missing (MapInfo.lectern_swap); so papers
## are left in the rooms and swapped about. While the room is empty and the lectern bare, the next
## class's paper lies on it to be lifted (sneaking, MapInfo.lectern_paper).

@onready var player: Player = Stage.player()

var map_info: MapInfo
## Its classroom (an index into LevelGen.halls).
var hall: int = -1


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	hall = int(extra) if extra != null else -1


## Whether it is a classroom's, a pigeonhole (see the class description).
func pigeonhole() -> bool:
	return map_info != null and map_info.world != null and hall >= 0 and hall < map_info.world.halls.size() and map_info.world.halls[hall]["kind"] == &"lecture"


## The exam paper on it now (MapInfo.lectern_slot), or 0.
func paper() -> int:
	if player == null or not pigeonhole():
		return 0
	return map_info.lectern_slot(hall)


## What is on it now, as [spell, tier]: its paper's subject and tier, or [&"", 0] for nothing.
func holds() -> Array:
	var code: int = paper()
	return [KeyRing.paper_spell(code), KeyRing.paper_tier(code)] if code != 0 else [&"", 0]


## Used: it swaps papers with the wizard (MapInfo.lectern_swap).
func take() -> void:
	if pigeonhole():
		map_info.lectern_swap(hall, global_position + Vector2(0, -40))


func _process(_delta: float) -> void:
	$Interactable.available = player != null and pigeonhole() and (paper() != 0 or not player.keyring.papers().is_empty())


func _ready() -> void:
	$Interactable.interacted.connect(take)
