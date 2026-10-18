extends StaticBody2D
class_name ExamDoor
## A door of an institute hall with a class in it (Institute, Timetable.TIMETABLED), across one of
## its doorways, kept by the timetable (MapInfo.hall_door_up): the library's stands open always, and a
## classroom's while its class is in session to a wizard enrolled in it (or inside it), shut
## otherwise; it never drops on the wizard. It has no lock: nothing else opens it. Its
## portcullis winches up and down (`lift`, printed by ExamDoorArt), and MapInfo.exam_doors keeps
## whether each is up, for what light and sight pass (MapInfo.solid_at).

## How fast the portcullis winches (its whole height a second, times this), and how far up it goes
## (as a switch gate's).
const LIFT_SPEED: float = 3.0
const UP_LIFT: float = 0.75

var map_info: MapInfo
## Its cell, its hall (an index into LevelGen.halls); whether it is up, and how far (the art).
var cell: Vector2i = Vector2i(-1, -1)
var hall: int = -1
var up: bool = true
var lift: float = UP_LIFT
## The physics layers it blocks on while down (from the prefab).
var _layer: int = 4


func setup(info: MapInfo, v: Vector2i, which: Variant) -> void:
	map_info = info
	cell = v
	hall = int(which)
	up = true
	collision_layer = 0
	info.exam_doors[v] = true


func _ready() -> void:
	_layer = collision_layer if collision_layer != 0 else 4
	if map_info == null:
		return
	collision_layer = 0


## What its hall teaches (for its plate): a lecture hall's subject now (MapInfo.subject_of; &"" for
## no class, and for any other hall).
func subject() -> StringName:
	if map_info == null or map_info.world == null:
		return &""
	if hall >= 0 and hall < map_info.world.halls.size() and map_info.world.halls[hall]["kind"] == &"lecture":
		return map_info.subject_of(hall)
	return &""


## What a classroom's class asks for now (for the paper beside its plate): [a department, the tier
## needed] (Timetable.needs), or [&"", 0] for nothing (tier I, no class, another hall).
func prereq() -> Array:
	if subject() == &"":
		return [&"", 0]
	return Timetable.needs(map_info.world.halls[hall]["dept"], tier())


## Whether its hall is the classroom holding the way on (Timetable.way_on_hall), which asks besides
## for an exam paper of another department (MapInfo.way_on_paper).
func way_on() -> bool:
	return map_info != null and map_info.world != null and hall >= 0 and hall == Timetable.way_on_hall(map_info.world)


## The tier its lecture hall teaches its subject at now (pips under its plate), or 0.
func tier() -> int:
	if map_info == null or map_info.world == null or hall < 0 or hall >= map_info.world.halls.size() or map_info.world.halls[hall]["kind"] != &"lecture":
		return 0
	return map_info.tier_of(hall)


## Whether it blocks the way.
func shut() -> bool:
	return collision_layer != 0


## Whether the wizard's body overlaps the door's.
func _holds_wizard() -> bool:
	var player: Player = map_info.player if map_info != null else null
	if player == null or not is_instance_valid(player) or player.collider == null or player.collider.shape == null:
		return false
	var mine: CollisionShape2D = $CollisionShape2D
	var a: Rect2 = mine.shape.get_rect()
	a = Rect2(mine.global_position + a.position * mine.global_scale, a.size * mine.global_scale)
	var b: Rect2 = player.collider.shape.get_rect()
	b = Rect2(player.collider.global_position + b.position * player.collider.global_scale, b.size * player.collider.global_scale)
	return a.intersects(b)


func _physics_process(delta: float) -> void:
	if map_info == null:
		return
	up = map_info.hall_door_up(hall)
	if up:
		collision_layer = 0
	elif not shut() and not _holds_wizard():
		collision_layer = _layer
	map_info.exam_doors[cell] = not shut()
	lift = move_toward(lift, 0.0 if shut() else UP_LIFT, LIFT_SPEED * delta)
