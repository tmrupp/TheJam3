class_name Spiderling
extends Node2D
## A spiderling, hatched from the spider's egg sac (EggSac). It runs along the floor at the wizard
## (SPEED, a little faster on a harder preset, Difficulty.speed), off ledges and down holes after
## them, hopping (HOP) up a step in its way or at the wizard just over it, and its touch bites
## (its HitBox). Any blow kills it (BroodWound); a stun (a hex bolt, a parry) stops it and its bite.
## After LIFE seconds it withers away, shrinking for WITHER. It goes with the spider. Moved only
## from here, by the level's cells: it has no body. Printed as a small spider seen from the side,
## dark with a pink mark, its legs stepping as it runs.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## How fast it runs (px/s), how hard it falls (px/s², at most MAX_FALL), how hard it hops (px/s up),
## and the least time between hops (seconds).
const SPEED: float = 170.0
const GRAVITY: float = 1800.0
const MAX_FALL: float = 1100.0
const HOP: float = 760.0
const HOP_REST: float = 0.8
## How near across (cells) the wizard must be over it for it to hop at them.
const HOP_NEAR: float = 1.6
## How far its middle sits over a floor and in from a wall (px), and its bite's reach (px).
const RADIUS: float = 26.0
const BITE_R: float = 28.0
## How big it is printed, against the measures its shapes are drawn at below.
const LOOK: float = 1.6
## Seconds it lives, and the last of them it spends withering.
const LIFE: float = 9.0
const WITHER: float = 0.6
## Its legs (in the measures it is drawn at, see LOOK): each femur and shank, where each foot
## stands along the way it runs (back first), how far a stride goes, and how high a foot lifts as
## it swings forward.
const FEMUR: float = 14.0
const SHANK: float = 18.0
const FEET: Array[float] = [-24.0, -11.0, 11.0, 24.0]
const STRIDE: float = 40.0
const STEP_LIFT: float = 6.0

var spider: Spider
var velocity: Vector2 = Vector2.ZERO
## Seconds since it hatched, whether it stands on a floor, the way it runs (+1 right, -1 left),
## seconds until it may hop again, and how far through its stride it is.
var age: float = 0.0
var on_floor: bool = false
var way: float = 1.0
var hop_wait: float = 0.0
var stride: float = 0.0
var stunner: Stunner
var bite: HitBox
var ink: InkCanvas


func _init() -> void:
	var wound: BroodWound = BroodWound.new()
	wound.name = "Wound"
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	add_child(stunner)
	bite = HIT_BOX.instantiate() as HitBox
	bite.name = "HitBox"
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = BITE_R
	(bite.get_node("CollisionShape2D") as CollisionShape2D).shape = reach
	(bite.get_node("Damager") as Damager).attacker = self
	add_child(bite)
	add_to_group(&"hex_target")
	add_to_group(&"spiderling")


func _ready() -> void:
	ink = InkCanvas.new()
	ink.top_level = true
	ink.z_as_relative = false
	ink.z_index = 3
	add_child(ink)


func _physics_process(delta: float) -> void:
	if spider == null or not is_instance_valid(spider) or spider.map_info == null:
		queue_free()
		return
	age += delta
	if age >= LIFE:
		queue_free()
		return
	var info: MapInfo = spider.map_info
	var w: LevelGen = info.world
	var player: Player = info.player if info.player != null and is_instance_valid(info.player) else null
	hop_wait = maxf(0.0, hop_wait - delta)
	if stunner.stunned():
		if on_floor:
			velocity.x = 0.0
	elif on_floor and player != null:
		var dx: float = player.global_position.x - global_position.x
		if absf(dx) > 8.0:
			way = signf(dx)
		velocity.x = way * SPEED * Difficulty.speed()
		var wall: bool = w.is_ground(info.cell_at(global_position + Vector2(way * (RADIUS + 6.0), 0.0)))
		var above: bool = absf(dx) < HOP_NEAR * spider.cell and player.global_position.y < global_position.y - spider.cell * 0.5
		if (wall or above) and hop_wait <= 0.0:
			velocity.y = -HOP
			on_floor = false
			hop_wait = HOP_REST
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var at: Vector2 = global_position
	var nx: float = at.x + velocity.x * delta
	if velocity.x != 0.0 and w.is_ground(info.cell_at(Vector2(nx + signf(velocity.x) * RADIUS, at.y))):
		velocity.x = 0.0
	else:
		at.x = nx
	var ny: float = at.y + velocity.y * delta
	if velocity.y >= 0.0:
		var under: Vector2i = info.cell_at(Vector2(at.x, ny + RADIUS))
		if w.is_ground(under):
			at.y = info.cell_position(under).y - spider.cell * 0.5 - RADIUS
			velocity.y = 0.0
			on_floor = true
		else:
			at.y = ny
			on_floor = false
	else:
		if w.is_ground(info.cell_at(Vector2(at.x, ny - RADIUS))):
			velocity.y = 0.0
		else:
			at.y = ny
		on_floor = false
	stride = fposmod(stride + absf(at.x - global_position.x) / (STRIDE * LOOK), 1.0)
	global_position = at


func _process(_delta: float) -> void:
	ink.begin()
	var size: float = LOOK * clampf((LIFE - age) / WITHER, 0.0, 1.0)
	var at: Vector2 = global_position
	var legs: Array[PackedVector2Array] = []
	var joints: Array[PackedVector2Array] = []
	for k: int in range(8):
		var i: int = k % 4
		var far: float = 1.0 if k < 4 else 0.8
		var phase: float = TAU * stride + (PI if (i % 2 == 0) == (k < 4) else 0.0)
		var going: float = 1.0 if on_floor and absf(velocity.x) > 1.0 else 0.0
		var hip: Vector2 = at + Vector2(way * (float(i) - 1.5) * 3.0, 0.0) * size
		var foot: Vector2 = at + Vector2(way * (FEET[i] * far + sin(phase) * STRIDE / TAU * going), RADIUS / LOOK - STEP_LIFT * going * maxf(0.0, cos(phase))) * size
		if not on_floor:
			# In the air its legs splay and dangle.
			foot = at + Vector2(way * FEET[i] * far * 1.1, RADIUS / LOOK * 0.6 + 4.0 * sin(age * 18.0 + float(k))) * size
		var knee: Vector2 = Spider._knee(hip, foot, FEMUR * size, SHANK * size)
		legs.append(Spider._limb(hip, knee, 3.0 * size, 2.4 * size))
		legs.append(Spider._limb(knee, foot, 2.4 * size, 1.0 * size))
		joints.append(RisoShapes.circle(knee, 1.6 * size, 6))
	legs.append_array(joints)
	var abdomen: PackedVector2Array = RisoShapes.ellipse(at + Vector2(-way * 11.0, -3.0) * size, 11.0 * size, 9.0 * size, 14)
	var head: PackedVector2Array = RisoShapes.ellipse(at + Vector2(way * 6.0, 0.0) * size, 7.0 * size, 6.0 * size, 12)
	ink.ink(RisoPrint.NIGHT, Spider.BODY_NIGHT, legs)
	ink.ink(RisoPrint.BLUE, Spider.BODY_BLUE * 0.8, legs, false)
	ink.ink(RisoPrint.NIGHT, Spider.BODY_NIGHT, [abdomen, head])
	ink.ink(RisoPrint.BLUE, Spider.BODY_BLUE, [abdomen, head], false)
	# Its mark (danger), and its eyes as bare paper.
	var mark: Array[PackedVector2Array] = [RisoShapes.circle(at + Vector2(-way * 11.0, -5.0) * size, 3.5 * size, 8)]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], mark)
	ink.ink(RisoPrint.PINK, 1.0, mark)
	var eyes: Array[PackedVector2Array] = [RisoShapes.circle(at + Vector2(way * 9.0, -2.0) * size, 1.8 * size, 6), RisoShapes.circle(at + Vector2(way * 6.0, -3.0) * size, 1.4 * size, 6)]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], eyes)
	if stunner.stunned():
		ink.ink(RisoPrint.ACCENT, 0.9, [Transform2D(age * 4.0, at + Vector2(0.0, -24.0)) * RisoShapes.sparkle(Vector2.ZERO, 7.0)])
	ink.finish()
