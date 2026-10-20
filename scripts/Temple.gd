extends Area2D
class_name Temple
## The altar of a sky temple (SkyArchetype.build_temples), locked by a sequence of winds: LENGTH.x to
## LENGTH.y steps, each a way (+1 right, -1 left), repeats and all, dealt with the level. It is
## entered by switching on vanes in its level (MapInfo.switch_vane, step): each vane switched on is
## the next step, its way the way it points. The right way lights the next step of the lock; the
## wrong way breaks the sequence and it starts again (from its first step, which that vane may
## itself be), a flash of pink as it does. A repeat is two vanes of the same way switched on in a
## row (or one switched off and on again). Switching a vane off enters nothing. Its progress is kept
## in the level record. With every step lit, interact and it opens, for good (the level record): its
## hoard of star clusters appears in its hall either side of it (SkyArchetype.TEMPLE_HOARD), and it
## shows where the whale is (WhaleHunt): its prompt says which world, wherever it swims (the whale
## is met then, if it was not). Nothing here draws from any RNG.

## How many steps its sequence has (from, to).
const LENGTH: Vector2i = Vector2i(5, 9)

var map_info: MapInfo
## Its sequence: the way each step must be (+1 right, -1 left), in order.
var sequence: Array[int] = []
## Seconds since it opened (-1 if it was open before this visit), since it last refused, and since
## its sequence was last broken (the art); its progress last frame.
var since_open: float = -1.0
var since_refused: float = 99.0
var since_broken: float = 99.0
var _last_progress: int = 0


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	sequence.clear()
	for w: Variant in (extra as Array if extra is Array else []):
		sequence.append(int(w))


## The progress of a lock of `steps` at `progress` once a vane pointing `way` is switched on: the
## next step lit if it is that way; else broken, back to the start (its first step lit, if that is
## the way).
static func step(steps: Array, progress: int, way: int) -> int:
	if steps.is_empty() or progress >= steps.size():
		return progress
	if int(steps[progress]) == way:
		return progress + 1
	return 1 if int(steps[0]) == way else 0


## How many steps of its sequence are lit.
func progress() -> int:
	if map_info == null:
		return 0
	return sequence.size() if opened() else mini(map_info.record().temple_progress, sequence.size())


## Whether step `i` is lit.
func lit(i: int) -> bool:
	return i < progress()


func all_lit() -> bool:
	return not sequence.is_empty() and progress() == sequence.size()


func opened() -> bool:
	return map_info != null and map_info.record().temple_open


func interaction_hint() -> Dictionary:
	if not opened():
		return {"text": "%d of %d winds" % [progress(), sequence.size()]} if not all_lit() else {}
	var run: RunState = map_info.run
	if run.bosses.has(&"whale"):
		return {"text": "the whale is slain"}
	return {"text": "the whale: world %d" % run.whale_x}


## Interact: with its whole sequence lit, it opens (and the whale is met, if it was not).
func use() -> void:
	if map_info == null or opened():
		return
	if not all_lit():
		since_refused = 0.0
		Wound.shake(3.0, 0.12)
		return
	map_info.record().temple_open = true
	WhaleHunt.start(map_info.run, map_info.coord)
	# Its hoard appears in its hall.
	for b: Dictionary in map_info.world.temples:
		if has_meta(&"cell") and b["altar"] == get_meta(&"cell"):
			for v: Vector2i in b["hoard"]:
				map_info.loader.place_cell(v, map_info.world.get_cell(v))
	map_info.save_run()
	since_open = 0.0
	RisoFx.burst(&"gain", global_position + Vector2(64.0, -120.0), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(6.0, 0.3)


func _process(delta: float) -> void:
	if since_open >= 0.0:
		since_open += delta
	since_refused += delta
	since_broken += delta
	var now: int = progress()
	if now < _last_progress:
		since_broken = 0.0
	_last_progress = now


func _ready() -> void:
	$Interactable.interacted.connect(use)
