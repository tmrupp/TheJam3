extends Node
class_name Warp
## Warp, a spell: Spell (Q, or the pad's X) sends you to a random floor in the level, then it
## recharges for COOLDOWN. Tiers (Abilities): I anywhere; II a floor you have not seen yet, while
## there is one (and a shorter cooldown); III into a secret room not yet opened, while there is
## one, which opens it (see MapInfo.open_secret).
## A warp takes a moment, in the three beats of a portal trip (see portal.gd), with the wizard held
## still: drawn into a tear in the air where they stand (DEPART), the view cuts to where they land,
## and they are pushed out of a tear there (ARRIVE). RisoPrint prints it (warp_depart, warp_arrive).
## The cast is decided and paid at once: `warping` is true until the wizard can move again.

const DEPART: float = 0.3
## Into the arrival, when the wizard is seen again, and when they can move.
const REVEAL: float = 0.16
const ARRIVE: float = 0.32

const COOLDOWN: float = 12.0
const COOLDOWN_II: float = 9.0

var level: int = 1
var recharge: float = 0.0
var warping: bool = false

@onready var player: Player = get_parent() as Player


func cooldown() -> float:
	return COOLDOWN_II if level >= 2 else COOLDOWN


## 0..1 toward ready, or 1 while ready (the spell orb shows it).
func readiness() -> float:
	return 1.0 if recharge <= 0.0 else 1.0 - clampf(recharge / cooldown(), 0.0, 1.0)


## The trip is over in a moment: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	recharge = maxf(0.0, recharge - delta)


## Its tier (Abilities): II to unseen floors (and a shorter cooldown); III into secret rooms.
func set_tier(n: int) -> void:
	level = n


## The Spell button, with warp in the slot: warp, if ready. Whether it went (stars are paid only then).
func cast_spell() -> bool:
	return cast() != null


## Warp, if ready. Returns the cell it will land in (the trip plays out over the next moment), or
## null.
func cast() -> Variant:
	var info: MapInfo = MapInfo.instance
	if warping or recharge > 0.0 or player == null or info == null or info.world == null or info.travelling or player.has_meta(&"portal_trip"):
		return null
	var to: Variant = pick(info)
	if to == null:
		return null
	var cell: Vector2i = to
	recharge = cooldown()
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"warp")
	_trip(info, cell)
	return cell


## The trip itself: drawn in here, out at `cell`.
func _trip(info: MapInfo, cell: Vector2i) -> void:
	warping = true
	# Kept on the wizard like a portal trip, so nothing else is used meanwhile.
	player.set_meta(&"portal_trip", true)
	var moving: bool = player.is_physics_processing()
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	RisoPrint.warp_depart(player)
	await get_tree().create_timer(DEPART).timeout
	if not is_instance_valid(player) or info.travelling:
		_done(moving)
		return
	var to: Vector2 = info.cell_position(cell)
	player.global_position = to
	_snap_camera()
	RisoPrint.warp_arrive(player, to)
	# Landed in a secret room: it opens.
	info.open_secret(info.secret_at(cell))
	await get_tree().create_timer(REVEAL).timeout
	RisoPrint.portal_reveal(player)
	player.visual_event.emit(&"teleport", to)
	await get_tree().create_timer(ARRIVE - REVEAL).timeout
	_done(moving)


func _done(moving: bool) -> void:
	warping = false
	if is_instance_valid(player):
		RisoPrint.portal_reveal(player)
		player.set_physics_process(moving)
		player.remove_meta(&"portal_trip")


## The view cuts to the landing at once, rather than sweeping across the level.
func _snap_camera() -> void:
	CameraControl.snap(player)


## Where a warp lands (see the tiers above), or null if there is nowhere.
func pick(info: MapInfo) -> Variant:
	var w: LevelGen = info.world
	if level >= 3:
		var rooms: Array[Vector2i] = []
		for id: int in range(w.secrets.size()):
			if (info.record().secrets as Dictionary).has(id):
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
		if [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return w.is_valid(v + d) and w.get_cell(v + d).type == LevelGen.Type.SPIKES):
			continue
		floors.append(v)
		if level >= 2 and not info.is_seen(v):
			unseen.append(v)
	var pool: Array[Vector2i] = unseen if not unseen.is_empty() else floors
	return pool[randi() % pool.size()] if not pool.is_empty() else null
