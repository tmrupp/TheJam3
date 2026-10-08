class_name WormSegment
extends RigidBody2D
## One segment of the worm (Worm), which moves it. A solid body on a layer of its own (WORM_LAYER),
## which the wizard's dash does not pass through as it does the enemy layer, so the worm walls off
## a tunnel as it passes, blocks a dash and can be stood on. Struck by bolts, dashes and parries
## through its Wound (WormWound) as any enemy is, but stunned only by a parry (its Stunner is
## parry_only). Only the head (make_head) has a HitBox, so only the head bites, and only a bite
## can be parried to stun it.
## Every other segment has thorns on one side: the half of it facing `spikes`, the flank of the
## body its worm chose as it came out of the rock (Worm). Touching that side hurts (its own HitBox, under a Thorns node
## that has no health or stun, so a parry against them only catches the hit and pushes off, as off
## any thorns), and a strike from that side glances off (guarded): the wizard has to get round to
## its bare side to cut it. While it is down in the rock, or burrowing away to die, it is not live:
## nothing touches or strikes it.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## Its physics layer (project settings: "Worm"; the wizard's prefab collides with it), and its bit.
const WORM_LAYER: int = 9
const WORM_BIT: int = 1 << (WORM_LAYER - 1)
## How far its thorns stand out from the body (px), and how squarely a strike must come from the
## thorny side to glance off (the dot of its way with the way they face).
const THORN_LEN: float = 22.0
const THORN_GUARD: float = 0.1

## The worm it belongs to.
var worm: Worm
## Its radius in pixels.
var radius: float = 22.0
## Whether it can be touched and struck (see set_live).
var live: bool = false
## Whether the worm shows it (out of the rock), and the way it faces (toward the head), for the art.
var shown: bool = false
var heading: Vector2 = Vector2.RIGHT
var wound: WormWound
var stunner: Stunner
## Its bite, on the head only.
var bite: HitBox
## The head has just bitten and is resting, harmless until its worm moves on again.
var recovering: bool = false
## Its thorns (every segment but the head), the touch that hurts on their side, and the way they
## face.
var thorns: Node2D
var thorn_box: HitBox
var spikes: Vector2 = Vector2.UP


func _init(of: Worm, r: float, hp: int) -> void:
	worm = of
	radius = r
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	lock_rotation = true
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = r
	shape.shape = circle
	add_child(shape)
	wound = WormWound.new()
	wound.name = "Wound"
	wound.hp = hp
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	stunner.parry_only = true
	add_child(stunner)
	thorns = Node2D.new()
	thorns.name = "Thorns"
	add_child(thorns)
	thorn_box = HIT_BOX.instantiate() as HitBox
	thorn_box.name = "ThornBox"
	# A half disc on the thorny side (facing +x, turned with `thorns`), reaching past the body.
	var half: PackedVector2Array = PackedVector2Array()
	for n: int in range(13):
		half.append(Vector2.from_angle(-PI * 0.5 + PI * float(n) / 12.0) * (r + THORN_LEN))
	var reach: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	reach.points = half
	(thorn_box.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	thorns.add_child(thorn_box)


## Give it the worm's bite: it is the head now (a head has no thorns).
func make_head() -> void:
	if bite != null:
		return
	if thorns != null:
		thorns.queue_free()
		thorns = null
		thorn_box = null
	bite = HIT_BOX.instantiate() as HitBox
	bite.name = "HitBox"
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = radius
	(bite.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	(bite.get_node("Damager") as Damager).touched_player.connect(_bit)
	add_child(bite)


## A bite met the wizard: rest the piece, leaving a moment to strike its head.
func _bit() -> void:
	if live and not recovering and worm != null:
		worm.bit(self)


## Make it live (solid, struck by bolts and dashes, and biting if it is the head) or not.
func set_live(on: bool) -> void:
	if on == live:
		return
	live = on
	collision_layer = WORM_BIT if on else 0
	if on:
		add_to_group(&"hex_target")
	else:
		remove_from_group(&"hex_target")


## Whether a strike heading `dir` comes from its thorny side, and glances off.
func guarded(dir: Vector2) -> bool:
	return thorns != null and dir != Vector2.ZERO and dir.normalized().dot(spikes) < -THORN_GUARD


## Whether its worm is stunned (they are stunned together, Worm).
func stunned() -> bool:
	return stunner.stunned()


## Keep the head's bite to when it is live, not resting and not stunned; thorns stay live during
## the rest, but not a stun. Its Stunner
## turns the bite back on when a stun ends, so this is checked every frame rather than once.
func sync_touch() -> void:
	var off: bool = not live or stunned()
	for box: HitBox in [bite, thorn_box]:
		var resting: bool = off or (box == bite and recovering)
		if box != null and box.collision != null and box.collision.disabled != resting:
			box.collision.set_deferred("disabled", resting)
