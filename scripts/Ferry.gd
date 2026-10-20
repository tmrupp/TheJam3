extends Node
class_name Ferry
## Ferry, a movement spell: press Dash to conjure a raft of spell light under your feet that sets off the
## way you face and shuttles back and forth along its line for as long as you stay in the level,
## turning back at rock: a moving platform of your own. Cast in the air, it catches you: the fall
## stops as it appears. Tiers (Abilities): I one raft out at once (another sends the oldest
## fading); II two; III three, and faster.

## The raft (FerryRaft) a cast conjures.
const RAFT: PackedScene = preload("res://prefabs/ferry_raft.tscn")
## Seconds between casts.
const COOLDOWN: float = 0.6
## How fast a raft glides (px/s): at tiers I and II, and at III.
const SPEED: float = 170.0
const SPEED_III: float = 230.0

## How fast a raft glides (px/s), and how many may be out at once.
var speed: float = SPEED
var most: int = 1
## The rafts out now, oldest first, and seconds until the next cast.
var rafts: Array[FerryRaft] = []
var wait: float = 0.0

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	player.elapse_ability_time_signal.connect(elapse)


## Its tier (Abilities): I one raft at 170 px/s; II two; III three, at 230 px/s.
func set_tier(n: int) -> void:
	speed = SPEED_III if n >= 3 else SPEED
	most = clampi(n, 1, 3)


func elapse(delta: float) -> void:
	wait = maxf(0.0, wait - delta)
	for i: int in range(rafts.size() - 1, -1, -1):
		if not is_instance_valid(rafts[i]) or rafts[i].is_queued_for_deletion():
			rafts.remove_at(i)


## The Dash button, with ferry in the movement slot: conjure a raft under the feet, setting off the way the
## wizard faces.
func cast_spell() -> bool:
	if wait > 0.0 or player.phasing:
		return false
	var facing: float = signf(player.sprite.scale.x) if player.sprite != null and player.sprite.scale.x != 0.0 else 1.0
	while rafts.size() >= most:
		var oldest: FerryRaft = rafts.pop_front()
		if is_instance_valid(oldest):
			oldest.fade_out()
	var raft: FerryRaft = RAFT.instantiate() as FerryRaft
	raft.velocity = Vector2(facing * speed, 0.0)
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(raft)
	raft.place(Vector2(player.global_position.x, player._feet_y() + FerryRaft.HALF_THICK))
	rafts.append(raft)
	player.velocity.y = minf(player.velocity.y, 0.0)
	wait = COOLDOWN
	return true


## Ready unless just cast: 0..1 as the short wait runs out (the spell's mark shows it).
func readiness() -> float:
	return 1.0 - wait / COOLDOWN


## A raft stays: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)
