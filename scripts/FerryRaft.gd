extends AnimatableBody2D
class_name FerryRaft
## A raft of spell light conjured by the ferry spell (Ferry): a one-way ledge, like a lift. It
## first rises RISE under the wizard's feet, lifting them onto it (off the floor, when cast there),
## then glides at `velocity` for the rest of its `life`, stopping against rock, then fades away.

## Half the raft's width and thickness (world pixels); its top is at its origin's y minus HALF_THICK.
const HALF_WIDTH: float = 70.0
const HALF_THICK: float = 12.0
## How long it takes to fade once its life is out, and how far ahead it looks for rock.
const FADE: float = 0.35
const LOOK_AHEAD: float = 16.0
## How far it rises before it glides, and how long that takes.
const RISE: float = 14.0
const RISE_TIME: float = 0.12

var velocity: Vector2 = Vector2.ZERO
var life: float = 2.5
## Seconds of life left, and how far through fading it is (0 until it starts, 1 gone).
var left: float = 0.0
var fade: float = 0.0
## Whether it has come to rest against rock, and how long it has been out.
var stopped: bool = false
var age: float = 0.0
## Where it is (world). Set outright each step, as a lift's is: a physics-synced body reverts
## nudges made to its position.
var at: Vector2 = Vector2.ZERO


func _ready() -> void:
	left = life
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(HALF_WIDTH * 2.0, HALF_THICK * 2.0)
	($CollisionShape2D as CollisionShape2D).shape = shape


## Put it at `at` (world) at once, without sweeping anything along the way (as MovingPlatform._place).
func place(to: Vector2) -> void:
	at = to
	sync_to_physics = false
	global_position = to
	sync_to_physics = true


func fading() -> bool:
	return left <= 0.0


## Start fading now (a newer raft replaces it).
func fade_out() -> void:
	left = 0.0


func _physics_process(delta: float) -> void:
	if left > 0.0:
		left = maxf(0.0, left - delta)
		age += delta
		if age <= RISE_TIME:
			var step_up: Vector2 = Vector2(0, -RISE * delta / RISE_TIME)
			if not _blocked(step_up):
				at += step_up
			global_position = at
			return
		if not stopped and velocity != Vector2.ZERO:
			var step: Vector2 = velocity * delta
			if _blocked(step):
				stopped = true
			else:
				at += step
		global_position = at
		return
	global_position = at
	fade += delta / FADE
	if fade >= 1.0:
		($CollisionShape2D as CollisionShape2D).set_deferred(&"disabled", true)
		queue_free()


## Whether moving by `step` would push its leading edge into rock.
func _blocked(step: Vector2) -> bool:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return false
	var d: Vector2 = step.normalized()
	var reach: Vector2 = Vector2(HALF_WIDTH, HALF_THICK) + Vector2(LOOK_AHEAD, LOOK_AHEAD)
	var ahead: Vector2 = at + step + Vector2(d.x * reach.x, d.y * reach.y)
	# Its two leading corners and its middle, so it never grazes a corner into the rock.
	var across: Vector2 = Vector2(-d.y, d.x) * (HALF_WIDTH if absf(d.y) > absf(d.x) else HALF_THICK) * 0.9
	return info.solid_at(ahead) or info.solid_at(ahead + across) or info.solid_at(ahead - across)
