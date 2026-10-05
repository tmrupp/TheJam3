class_name Puff
extends StaticBody2D
## A cloud that gives way, in sky levels (MapInfo.World.populate_sky, and the stepping stones of
## the causeways between clusters, MapInfo.World.link_isles): a ledge of cloud (one-way, like a
## platform) that holds for STAND seconds once the wizard lands on it, thinning as it goes, then
## lets them through: once touched it goes, whether they stay or jump off. It gathers again REFORM
## seconds later, once the wizard is clear of it.

const STAND: float = 0.35
const REFORM: float = 3.0

@onready var player: Player = get_node_or_null("/root/Main/Player") as Player

## Seconds since it was first stood on (0..STAND), or -1 untouched.
var stood: float = -1.0
## Seconds since it gave way, or -1 while it holds.
var gone: float = -1.0


## How far it has thinned toward giving way: 0 whole .. 1 about to go.
func worn() -> float:
	return clampf(stood / STAND, 0.0, 1.0) if stood >= 0.0 else 0.0


func holds() -> bool:
	return gone < 0.0


func _physics_process(delta: float) -> void:
	if gone >= 0.0:
		gone += delta
		if gone >= REFORM and not _overlapped():
			gone = -1.0
			stood = -1.0
			$CollisionShape2D.set_deferred("disabled", false)
		return
	if stood < 0.0 and _stood_on():
		stood = 0.0
	if stood >= 0.0:
		stood += delta
		if stood >= STAND:
			gone = 0.0
			$CollisionShape2D.set_deferred("disabled", true)


func _stood_on() -> bool:
	if player == null or not is_instance_valid(player) or not player.is_on_floor():
		return false
	for i: int in range(player.get_slide_collision_count()):
		var hit: KinematicCollision2D = player.get_slide_collision(i)
		if hit.get_collider() == self and hit.get_normal().y < -0.5:
			return true
	return false


## Whether the wizard is inside where it would gather (it waits for them to leave).
func _overlapped() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var d: Vector2 = player.global_position - global_position
	return absf(d.x) < 100.0 and d.y > -110.0 and d.y < 10.0
