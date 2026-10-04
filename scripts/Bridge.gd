extends StaticBody2D
## One plank of a chasm's bridge, in cemetery levels (MapInfo.World.carve_chasms). Until the
## chasm's bell is rung (Bell) it is only a faint outline and nothing stands on it; rung, the
## planks lay themselves across one after another from the bell's side and stay, a ledge to stand
## on like a platform's (one-way).

## Seconds between one plank and the next as the bridge lays itself.
const STAGGER: float = 0.08

var map_info: MapInfo
## The number of the chasm it spans.
var chasm: int = -1
## 0 not there .. 1 laid (the art eases it in).
var laid: float = 0.0
var laying: bool = false
var wait: float = 0.0


func setup(info: MapInfo, _v: Vector2i, id: int) -> void:
	map_info = info
	chasm = id
	if info.bridge_up(id):
		laid = 1.0
	_sync()


func up() -> bool:
	return laid >= 1.0 or laying


## The bell was rung: lay this plank, after the ones nearer the bell.
func raise() -> void:
	if up():
		return
	laying = true
	var order: int = 0
	if map_info != null and has_meta(&"cell"):
		var me: Vector2i = get_meta(&"cell")
		for node: Node in map_info.map_elements.get_children():
			if node.has_method("ring") and int(node.get("chasm")) == chasm and node.has_meta(&"cell"):
				order = absi(me.x - (node.get_meta(&"cell") as Vector2i).x)
	wait = STAGGER * float(order)
	_sync()


func _physics_process(delta: float) -> void:
	if not laying:
		return
	if wait > 0.0:
		wait -= delta
		return
	laid = minf(1.0, laid + delta * 5.0)
	if laid >= 1.0:
		laying = false


func _sync() -> void:
	# Solid as soon as it starts to lay, so the wizard is never dropped mid-crossing.
	var solid: bool = laid >= 1.0 or laying
	$CollisionShape2D.set_deferred("disabled", not solid)
	$Sprite2D.visible = solid
