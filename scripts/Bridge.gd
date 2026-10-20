extends StaticBody2D
class_name Bridge
## One plank of a chasm's bridge, in cemetery levels (Chasms.carve). Until the
## chasm's bell is rung (Bell) it is only a faint outline and nothing stands on it; rung, the
## planks lay themselves across one after another from the bell's side and stay. It is a bridge of
## the dead: it bears the wizard, a ledge like a platform's (one-way), only while the flame of the
## lantern they carry is out (MapInfo.flame_lit: snuffed at a font, Snuffer, or no lantern to
## carry). While it burns the planks are a ghost of themselves and the wizard drops through, so a
## dash, which lights the flame again, drops them into the chasm. The bridge sags: level with the
## shore at either end, lowest in the middle (SAG), each plank lying along its stretch of the curve.

## Seconds between one plank and the next as the bridge lays itself.
const STAGGER: float = 0.08
## How far the middle of a bridge sags below its shores (px), whatever its length.
const SAG: float = 44.0
## Where its ledge lies in the prefab, unsagged (its own units).
const LEDGE_Y: float = -12.0
## How fast it turns from a ghost to firm and back (its whole way a second, times this).
const FIRM_SPEED: float = 4.0

var map_info: MapInfo
## The number of the chasm it spans.
var chasm: int = -1
## 0 not there .. 1 laid (the art eases it in).
var laid: float = 0.0
var laying: bool = false
var wait: float = 0.0
## 0 a ghost .. 1 bearing (the art eases between them as the flame goes out or burns).
var firm: float = 0.0
## How far its left and right ends hang below the shore (px), from the bridge's sag.
var sag_left: float = 0.0
var sag_right: float = 0.0


func setup(info: MapInfo, v: Vector2i, id: int) -> void:
	map_info = info
	chasm = id
	if info.bridge_up(id):
		laid = 1.0
	if info.world != null and id >= 0 and id < info.world.chasms.size():
		var planks: Array = info.world.chasms[id]["planks"]
		var i: int = planks.find(v)
		if i >= 0:
			sag_left = sag_at(float(i) / float(planks.size()))
			sag_right = sag_at(float(i + 1) / float(planks.size()))
	# Its ledge along its stretch of the curve (the prefab is drawn four times over, so its own
	# units are a quarter of a pixel).
	var col: CollisionShape2D = $CollisionShape2D
	var across: float = float(info.tile_map.tile_set.tile_size.x) * info.tile_map.global_scale.x if info.tile_map != null else 128.0
	col.position.y = LEDGE_Y + (sag_left + sag_right) * 0.5 / scale.y
	col.rotation = atan2(sag_right - sag_left, across)
	_sync()


## How far below its shores a bridge hangs `u` of the way across (0 to 1).
static func sag_at(u: float) -> float:
	return SAG * sin(PI * clampf(u, 0.0, 1.0))


func up() -> bool:
	return laid >= 1.0 or laying


## Whether it bears the wizard now: laid (or laying) while the flame they carry is out.
func bears() -> bool:
	return up() and (map_info == null or not map_info.flame_lit())


## A bell was rung (at cell `from`): lay this plank, after the ones nearer that bell.
func raise(from: Vector2i = Vector2i(-1, -1)) -> void:
	if up():
		return
	laying = true
	var order: int = 0
	if from.x >= 0 and has_meta(&"cell"):
		order = absi((get_meta(&"cell") as Vector2i).x - from.x)
	wait = STAGGER * float(order)
	_sync()


func _physics_process(delta: float) -> void:
	firm = move_toward(firm, 1.0 if bears() else 0.0, FIRM_SPEED * delta)
	_sync()
	if not laying:
		return
	if wait > 0.0:
		wait -= delta
		return
	laid = minf(1.0, laid + delta * 5.0)
	if laid >= 1.0:
		laying = false


func _sync() -> void:
	# Solid as soon as it starts to lay, so a wizard in the dark is never dropped mid-crossing.
	var solid: bool = bears()
	var col: CollisionShape2D = $CollisionShape2D
	if col.disabled == solid:
		col.set_deferred("disabled", not solid)
	$Sprite2D.visible = solid
