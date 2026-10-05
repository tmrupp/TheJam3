extends Node2D
## A watcher's shot. It flies straight and bursts on the first rock it meets, unless it rebounds
## (`bounces` > 0, a sky level's watchers, see MapInfo.World.populate_sky): then it glances off
## that many walls first, each bounce found by a sweep ahead of it (its hit box lets rock pass
## while it still has bounces). Parried, it turns back on its shooter as ever (Parry).
@onready var area: Area2D = $HitBox
@onready var player: Player = $"/root/Main/Player"
var velocity: Vector2 = Vector2(1, 1).normalized()
var exclude: Array
## Walls left to glance off.
var bounces: int = 0
## Seconds since the last bounce (the art flashes).
var since_bounce: float = 99.0
## Bodies its sweep glances off: rock and ledges (as its hit box sees them).
const SOLID_MASK: int = 32

func setup(v: Vector2, ignore: Array, sender: Node) -> void:
	velocity = v
	exclude = ignore
	$HitBox/Damager.attacker = sender

func touch (other: Node) -> void:
	if other in exclude or bounces > 0:
		return
	RisoFx.burst(&"impact", global_position, -velocity.normalized())
	queue_free()

func _ready() -> void:
	area.connect("body_entered", touch)

func _process(delta: float) -> void:
	since_bounce += delta
	var step: Vector2 = velocity * delta
	if bounces > 0 and step != Vector2.ZERO:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * 8.0, SOLID_MASK)
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit["normal"] as Vector2) != Vector2.ZERO:
			var normal: Vector2 = hit["normal"]
			velocity = velocity.bounce(normal)
			bounces -= 1
			since_bounce = 0.0
			global_position = (hit["position"] as Vector2) + normal * 6.0
			RisoFx.burst(&"impact", global_position, normal)
			return
	position += step
