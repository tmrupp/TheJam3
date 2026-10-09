extends Node
class_name Levitate
## Levitate, a spell: press Spell in the air to stop falling and hold your height, moving
## sideways at walking pace, for up to six seconds, until you press Spell again (or land).
## One float per touch of the ground (or a moon). Tiers: II lets the stick drift you slowly up and down while floating;
## III brings the float back without landing.

## The stick moves you up and down while floating (tier II).
var drift: bool = false
## A new float is ready the moment the last one ends, without landing (tier III).
var free_recast: bool = false
## A float is ready (comes back on landing).
var charged: bool = true
## The longest a float can hold the wizard up.
const FLOAT_TIME: float = 6.0
## Seconds left in this float, shown by the spell orb's draining ring.
var remaining: float = 0.0

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	player.elapse_ability_time_signal.connect(elapse)


## A float runs out even when the wizard keeps still.
## Its tier (Abilities): II drifts up and down; III recasts without landing.
func set_tier(n: int) -> void:
	drift = n >= 2
	free_recast = n >= 3


## The Spell button, with levitate in the slot: float, or let go.
func cast_spell() -> bool:
	toggle()
	return true


## Ready while a float is charged (or one is under way, to let go): 1, else 0.
func readiness() -> float:
	return 1.0 if charged or floating() else 0.0


## While floating: (the fraction of FLOAT_TIME left, seconds left); x < 0 when not.
func running() -> Vector2:
	if not floating():
		return Vector2(-1.0, 0.0)
	return Vector2(clampf(remaining / FLOAT_TIME, 0.0, 1.0), remaining)


func elapse(delta: float) -> void:
	if not floating():
		remaining = 0.0
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		stop()


func floating() -> bool:
	return player != null and player.levitating


func toggle() -> void:
	if floating():
		stop()
	elif charged and not player.is_on_floor():
		start()


func start() -> void:
	charged = false
	remaining = FLOAT_TIME
	player.levitating = true
	player.velocity.y = 0.0
	player.visual_event.emit(&"levitate", player.global_position)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"levitate")


func stop() -> void:
	player.levitating = false
	remaining = 0.0
	if free_recast:
		charged = true


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if player.is_on_floor():
		if floating():
			stop()
		charged = true
