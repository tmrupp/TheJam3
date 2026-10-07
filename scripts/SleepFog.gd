extends Node2D
class_name SleepFog
## A bank of sleep fog, in cemetery levels: a low cloud lying over a floor, drifting slowly to and
## fro. While the wizard is in it they are drowsy (Player.is_drowsy): the spell in the slot does
## nothing, a levitate float or an astral projection ends, and awareness stops sensing; the robe
## greys and the spell orb dims. It wears off a moment after leaving the fog.

## Its size (an ellipse, centred a little over the floor), and how far and how slowly it drifts.
const SIZE: Vector2 = Vector2(600, 240)
const RISE: float = 50.0
const DRIFT: float = 220.0
const PERIOD: float = 14.0

var home: Vector2 = Vector2.ZERO
var phase: float = 0.0
var t: float = 0.0

@onready var player: Player = Stage.player()


func setup(_info: MapInfo, v: Vector2i) -> void:
	home = global_position
	phase = float(posmod(v.x * 37 + v.y * 11, 100)) / 100.0 * TAU


## The middle of the cloud now.
func middle() -> Vector2:
	return global_position + Vector2(0, -RISE)


## Whether world point `p` is inside the cloud.
func covers(p: Vector2) -> bool:
	var d: Vector2 = (p - middle()) / (SIZE * 0.5)
	return d.length_squared() <= 1.0


func _physics_process(delta: float) -> void:
	t += delta
	if home == Vector2.ZERO:
		home = global_position
	global_position = home + Vector2(sin(t * TAU / PERIOD + phase) * DRIFT, 0)
	if player != null and is_instance_valid(player) and covers(player.global_position + Vector2(0, -40)):
		player.make_drowsy()
