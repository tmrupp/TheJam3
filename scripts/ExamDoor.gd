extends StaticBody2D
class_name ExamDoor
## A door of an institute hall with a class in it (Institute, Timetable.TIMETABLED), across one of
## its doorways, kept by the timetable (MapInfo.hall_door_up): a lecture hall's or the library's
## stands open while its class is in session and is shut while it is not. The exam hall's are the gate
## of the institute (docs/REGIONS_PLAN.md §7): open only while the exam is in session (the last
## period), until the exam begins, when the wizard is inside the hall (MapInfo.exam_begin); then they
## drop, as soon as the wizard is clear of them, and the hall is shut off with its master and
## students, until the master falls (Scholar._fallen, MapInfo.exam_passed). Then they rise for good:
## the level record keeps the exam passed (LevelRecord.exams). A death of the wizard's own before then
## brings the master back, the exam to sit afresh. It has no lock: nothing else opens it. Its
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


## Whether its exam has been passed (it stays up for good).
func passed() -> bool:
	return map_info != null and map_info.record().exams.has(hall)


## The ability the master of its hall teaches (for its plate), or &"" when none is known.
func subject() -> StringName:
	if map_info == null or map_info.world == null:
		return &""
	for v: Vector2i in map_info.world.objects_of(LevelGen.Type.MASTER):
		var extra: Variant = map_info.world.get_cell(v).extra_info
		if extra is Dictionary and int((extra as Dictionary).get("hall", -1)) == hall:
			return StringName((extra as Dictionary).get("ability", &""))
	return &""


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
