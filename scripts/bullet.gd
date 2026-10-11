extends Node2D
class_name Bullet
## A watcher's shot. It flies straight and bursts on the first rock it meets, unless it rebounds
## (`bounces` > 0, a sky level's watchers, see SkyArchetype.populate): then it glances off
## that many walls first, each bounce found by a sweep ahead of it (its hit box lets rock pass
## while it still has bounces). Parried, it turns back on its shooter as ever (Parry).
@onready var area: Area2D = $HitBox
@onready var player: Player = Stage.player()
var velocity: Vector2 = Vector2(1, 1).normalized()
var exclude: Array
## Walls left to glance off.
var bounces: int = 0
## Seconds since the last bounce (the art flashes).
var since_bounce: float = 99.0
## A seed the bramble's bulb spat (BrambleBulb), printed as one; parried, it flies back into the
## bulb as any shot does.
var seed: bool = false
## An arrow a crag tower's crossbow loosed (Crossbow), printed as one; parried, it flies back as any
## shot does, only as far as the tower's wall. It wounds the first enemy in its way (ARROW_DAMAGE,
## however hard it is to stun; a shield takes it whole), and pierces the spider's back
## (Spider.pierce): an arrow meeting its body puts out an eye, whatever it is doing. It passes
## crossbows by, and what is not an enemy.
var arrow: bool = false
## How much an arrow wounds an enemy, and how near its way an enemy must be (pixels) for it to strike.
const ARROW_DAMAGE: int = 1
const ARROW_REACH: float = 30.0
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
	if arrow and step != Vector2.ZERO and _strike(global_position, global_position + step):
		RisoFx.burst(&"impact", global_position, -velocity.normalized())
		queue_free()
		return
	position += step


## An arrow's step from `from` to `to`: whether it struck an enemy on the way (the nearest it
## meets), wounding it (see `arrow`).
func _strike(from: Vector2, to: Vector2) -> bool:
	var dir: Vector2 = velocity.normalized()
	var spider: Spider = Spider.body_across(get_tree(), from, to)
	if spider != null:
		spider.pierce(dir)
		return true
	var best: Node2D = null
	for e: Node in get_tree().get_nodes_in_group(&"hex_target"):
		var body: Node2D = e as Node2D
		if body == null or e is Spider or e is Crossbow or e in exclude or e.is_queued_for_deletion() or e.get_node_or_null("Wound") == null:
			continue
		var at: Vector2 = body.global_position
		var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(from, to, at + Vector2(0, HexBolt.SPAN_DOWN), at - Vector2(0, HexBolt.SPAN_UP))
		if near[0].distance_to(near[1]) <= ARROW_REACH and (best == null or from.distance_squared_to(at) < from.distance_squared_to(best.global_position)):
			best = body
	if best == null:
		return false
	var shield: Shield = Shield.of(best)
	if shield != null and shield.absorb(false, dir):
		return true
	var wound: Wound = best.get_node("Wound") as Wound
	wound.hit(maxi(ARROW_DAMAGE, wound.least), dir)
	return true
