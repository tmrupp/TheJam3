extends Node
class_name Ferry
## Ferry, a spell: press Spell to conjure a raft of spell light under your feet that glides the way
## you aim (straight ahead when you aim nowhere), carrying you, until it fades. Cast in the air, it
## catches you: the fall stops as it appears. It stops against
## rock and waits there. Tiers (Abilities): II the raft lasts longer, III it is faster and two can
## be out at once (a third replaces the oldest).

## The raft (FerryRaft) a cast conjures.
const RAFT: PackedScene = preload("res://prefabs/ferry_raft.tscn")
## Seconds between casts.
const COOLDOWN: float = 0.6

## How long a raft lasts, how fast it glides (px/s), and how many may be out at once.
var life: float = 2.5
var speed: float = 170.0
var most: int = 1
## The rafts out now, oldest first, and seconds until the next cast.
var rafts: Array[FerryRaft] = []
var wait: float = 0.0

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	player.elapse_ability_time_signal.connect(elapse)


## Its tier (Abilities): I a raft of 2.5 s at 170 px/s; II 3.5 s; III 230 px/s and two at once.
func set_tier(n: int) -> void:
	life = 3.5 if n >= 2 else 2.5
	speed = 230.0 if n >= 3 else 170.0
	most = 2 if n >= 3 else 1


func elapse(delta: float) -> void:
	wait = maxf(0.0, wait - delta)
	for i: int in range(rafts.size() - 1, -1, -1):
		if not is_instance_valid(rafts[i]) or rafts[i].is_queued_for_deletion():
			rafts.remove_at(i)


## The Spell button, with ferry in the slot: conjure a raft under the feet, gliding the way aimed.
func cast_spell() -> bool:
	if wait > 0.0 or player.phasing:
		return false
	var aim: Vector2 = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))
	if aim == Vector2.ZERO:
		aim = Vector2(signf(player.sprite.scale.x) if player.sprite != null and player.sprite.scale.x != 0.0 else 1.0, 0.0)
	while rafts.size() >= most:
		var oldest: FerryRaft = rafts.pop_front()
		if is_instance_valid(oldest):
			oldest.fade_out()
	var raft: FerryRaft = RAFT.instantiate() as FerryRaft
	raft.velocity = aim.normalized() * speed
	raft.life = life
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(raft)
	raft.place(Vector2(player.global_position.x, player._feet_y() + FerryRaft.HALF_THICK))
	rafts.append(raft)
	player.velocity.y = minf(player.velocity.y, 0.0)
	wait = COOLDOWN
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"ferry")
	return true


## Ready unless just cast: 0..1 as the short wait runs out (the spell's mark shows it).
func readiness() -> float:
	return 1.0 - wait / COOLDOWN


## While the newest raft is out: (the share of its life left, seconds left); x < 0 when none is.
func running() -> Vector2:
	for i: int in range(rafts.size() - 1, -1, -1):
		var raft: FerryRaft = rafts[i]
		if is_instance_valid(raft) and not raft.fading():
			return Vector2(clampf(raft.left / raft.life, 0.0, 1.0), raft.left)
	return Vector2(-1.0, 0.0)
