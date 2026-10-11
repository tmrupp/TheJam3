extends Area2D
class_name Temple
## A small temple on an island, in some sky levels (SkyArchetype.place_temple). Shut, its door shows
## a sequence of winds: the way the wind must blow in each of SPAN levels along its row, its own in
## the middle, each lit while that level's vanes are set to blow it (Rules.wind_of: the setting, not
## the gusts of the moment), so opening one means travelling the row (on foot or by balloon) and
## setting each level's vanes in turn. With every one lit, interact and it opens, for good (the
## level record), and shows where the whale is (WhaleHunt): its prompt says which world, wherever it
## swims (the whale is met then, if it was not). Nothing here draws from any RNG.

## How many levels along its row its sequence of winds covers (its own in the middle).
const SPAN: int = 3

var map_info: MapInfo
## The way the wind must blow in each level of its sequence (+1 right, -1 left), from the left.
var winds: Array[int] = []
## Seconds since it opened (-1 if it was open before this visit), and since it last refused (the art).
var since_open: float = -1.0
var since_refused: float = 99.0


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	winds.clear()
	for w: Variant in (extra as Array if extra is Array else []):
		winds.append(int(w))


## The level the `i`th wind of its sequence is for.
func place_of(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return map_info.coord + Vector2i(i - SPAN / 2, 0)


## Whether the `i`th level's vanes are set to blow the way its sequence asks.
func lit(i: int) -> bool:
	if map_info == null or i >= winds.size():
		return false
	var wind: int = WhaleHunt.wind_at(map_info.run, place_of(i))
	return wind != 0 and signi(wind) == winds[i]


func all_lit() -> bool:
	return winds.size() == SPAN and range(SPAN).all(func(i: int) -> bool: return lit(i))


func opened() -> bool:
	return map_info != null and map_info.record().temple_open


func interaction_hint() -> Dictionary:
	if not opened():
		return {"text": "the winds are not right"} if not all_lit() else {}
	var run: RunState = map_info.run
	if run.bosses.has(&"whale"):
		return {"text": "the whale is slain"}
	return {"text": "the whale: world %d" % run.whale_x}


## Interact: with its sequence of winds all set, it opens (and the whale is met, if it was not).
func use() -> void:
	if map_info == null or opened():
		return
	if not all_lit():
		since_refused = 0.0
		Wound.shake(3.0, 0.12)
		return
	map_info.record().temple_open = true
	WhaleHunt.start(map_info.run, map_info.coord)
	map_info.save_run()
	since_open = 0.0
	RisoFx.burst(&"gain", global_position + Vector2(64.0, -120.0), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(6.0, 0.3)


func _process(delta: float) -> void:
	if since_open >= 0.0:
		since_open += delta
	since_refused += delta


func _ready() -> void:
	$Interactable.interacted.connect(use)
