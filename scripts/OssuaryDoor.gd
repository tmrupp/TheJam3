extends StaticBody2D
class_name OssuaryDoor
## An ossuary door, across a doorway of a cemetery level's second crypt where the seed deals one
## (Rules.ossuary_at, Crypts.ossuary): a door of stacked skulls that drinks darkness. Interact and
## the wizard pours into it the charges of darkness they carry (MapInfo.pour_ossuary), as many as it
## still wants; it keeps what was poured (LevelRecord.poured, by the crypt, shared by the crypt's
## doorways) and opens for good once it has had its fill (Rules.ossuary_fill: more deeper), which one
## level's fonts seldom give. Behind it, the crypt's hoard.

## How fast it sinks open (its whole height a second, times this), for the art.
const OPEN_SPEED: float = 1.5
## The ways an ossuary door can be built (OssuaryArt): a square-topped arch, a bare wall of skulls,
## a lintel on two jambs; how many there are, and the way every door is built: the lintel.
enum Style { ARCH, WALL, LINTEL }
const STYLES: int = 3
const STYLE: Style = Style.LINTEL

var map_info: MapInfo
## Its cell, the number of the crypt it shuts, and the charges it drinks before it opens.
var cell: Vector2i = Vector2i(-1, -1)
var crypt: int = 0
var fill: int = 1
## How it is built (see STYLES), for the art.
var style: Style = STYLE
## 0 shut .. 1 sunk open (the art eases it down).
var sunk: float = 0.0
## How long ago (s) darkness was last poured in, for the art.
var poured_at: float = INF


func setup(info: MapInfo, v: Vector2i, how: Variant) -> void:
	map_info = info
	cell = v
	var parts: Array = how
	crypt = int(parts[0])
	fill = int(parts[1])
	if is_open():
		sunk = 1.0
		$CollisionShape2D.disabled = true


## The charges poured in so far.
func poured() -> int:
	return int(map_info.record().poured.get(crypt, 0)) if map_info != null else 0


func is_open() -> bool:
	return poured() >= fill


## Whether there is darkness to pour, and room for it.
func can_pour() -> bool:
	return map_info != null and map_info.run != null and not is_open() and map_info.run.dark_charges > 0


func pour() -> void:
	if can_pour() and map_info.pour_ossuary(crypt, fill, global_position) > 0:
		poured_at = 0.0
		# Open now, even where the level sleeps round it and its physics step does not run.
		if is_open():
			$CollisionShape2D.set_deferred("disabled", true)


func interaction_hint() -> Dictionary:
	return {"text": "%d / %d" % [poured(), fill]} if not is_open() else {}


func _process(delta: float) -> void:
	($Pour/Interactable as Interactable).available = can_pour()
	poured_at += delta


func _physics_process(delta: float) -> void:
	var open: bool = is_open()
	var col: CollisionShape2D = $CollisionShape2D
	if col.disabled != open:
		col.set_deferred("disabled", open)
	sunk = move_toward(sunk, 1.0 if open else 0.0, OPEN_SPEED * delta)


func _ready() -> void:
	($Pour/Interactable as Interactable).interacted.connect(pour)
