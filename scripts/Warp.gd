extends Node
class_name Warp
## Warp, a spell: Spell (Q, or the pad's X) sends you to a random floor in the level, then it
## recharges for COOLDOWN. Tiers (Abilities): I anywhere; II a floor you have not seen yet, while
## there is one (and a shorter cooldown); III into a secret room not yet opened, while there is
## one, which opens it (see MapInfo.open_secret).

const COOLDOWN: float = 12.0
const COOLDOWN_II: float = 9.0

var level: int = 1
var recharge: float = 0.0

@onready var player: Player = get_parent() as Player


func cooldown() -> float:
	return COOLDOWN_II if level >= 2 else COOLDOWN


## 0..1 toward ready, or 1 while ready (the spell orb shows it).
func readiness() -> float:
	return 1.0 if recharge <= 0.0 else 1.0 - clampf(recharge / cooldown(), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	recharge = maxf(0.0, recharge - delta)


## Warp, if ready. Returns the cell landed in, or null.
func cast() -> Variant:
	var info: MapInfo = MapInfo.instance
	if recharge > 0.0 or player == null or info == null or info.world == null or info.travelling:
		return null
	var to: Variant = pick(info)
	if to == null:
		return null
	var cell: Vector2i = to
	var from: Vector2 = player.global_position
	player.global_position = info.cell_position(cell)
	player.velocity = Vector2.ZERO
	player.reset_fourier_motion()
	player.visual_event.emit(&"teleport", player.global_position)
	RisoFx.burst(&"gain", from, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.EYE])
	RisoFx.burst(&"gain", player.global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.EYE])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"warp")
	# Landed in a secret room: it opens.
	info.open_secret(info.secret_at(cell))
	recharge = cooldown()
	return cell


## Where a warp lands (see the tiers above), or null if there is nowhere.
func pick(info: MapInfo) -> Variant:
	var w: MapInfo.World = info.world
	if level >= 3:
		var rooms: Array[Vector2i] = []
		for id: int in range(w.secrets.size()):
			if (info.record().get("secrets", {}) as Dictionary).has(id):
				continue
			var room: Array = w.secrets[id]["room"]
			rooms.append(room[room.size() - 1])
		if not rooms.is_empty():
			return rooms[randi() % rooms.size()]
	var floors: Array[Vector2i] = []
	var unseen: Array[Vector2i] = []
	var here: Vector2i = info.cell_at(player.global_position)
	for v: Vector2i in w.empties:
		if v == here or not w.ground_below(v) or info.solid_at(info.cell_position(v)):
			continue
		# Not into thorns.
		if [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return w.is_valid(v + d) and w.get_cell(v + d).type == MapInfo.Type.SPIKES):
			continue
		floors.append(v)
		if level >= 2 and not info.is_seen(v):
			unseen.append(v)
	var pool: Array[Vector2i] = unseen if not unseen.is_empty() else floors
	return pool[randi() % pool.size()] if not pool.is_empty() else null
