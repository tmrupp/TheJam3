class_name Shield
extends Node2D
## A shield an enemy carries, in sky levels (SkyArchetype.populate): a ring of pink plates round it
## (RisoWard), one for each hex bolt it can still take, that takes the bolts meant for it, a plate
## breaking with each, until the last goes after `hp` hits. A parried shot (a reflected bolt,
## HexBolt.reflected) breaks it at once. While it holds, bolts neither wound nor stun what it
## guards.

const RADIUS: float = 46.0
## How fast the ring of plates turns (radians a second).
const SPIN: float = 0.6

## Hits a shield takes before it breaks (a parried shot breaks it at once).
const HP: int = 3

var hp: int = HP
## Hits it can take when whole (the cracks are drawn by how many it has taken).
var full: int = HP
## Seconds since it was last struck (it flashes), and since it broke (-1 while it holds).
var since_hit: float = 99.0
var since_broke: float = -1.0
var ink: InkCanvas
var t: float = 0.0
## The plates broken so far: [the angle each broke at, seconds since], while their shards fly.
var _broken: Array[Vector2] = []


static func of(host: Node) -> Shield:
	return host.get_node_or_null("Shield") as Shield if host != null else null


func holds() -> bool:
	return hp > 0


## A bolt struck its host (heading `dir`): if it holds it takes the bolt, and true comes back.
func absorb(reflected: bool, dir: Vector2) -> bool:
	if hp <= 0:
		return false
	var was: int = hp
	hp = 0 if reflected else hp - 1
	since_hit = 0.0
	for i: int in range(hp, was):
		_broken.append(Vector2(RisoWard.plate_angle(i, full, _spin()), 0.0))
	var at: Vector2 = global_position - dir.normalized() * RADIUS * 0.8
	if hp <= 0:
		since_broke = 0.0
		RisoFx.burst(&"gain", global_position, dir, [RisoPrint.PINK, RisoPrint.BLUE])
		Wound.shake(8.0, 0.18)
	else:
		RisoFx.burst(&"hit", at, -dir, [RisoPrint.PINK, RisoPrint.NIGHT])
		Wound.shake(4.0, 0.1)
	return true


func _ready() -> void:
	full = maxi(full, hp)
	z_index = 3
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	add_child(ink)


func _process(delta: float) -> void:
	t += delta
	since_hit += delta
	if since_broke >= 0.0:
		since_broke += delta
	# Centred on what its host's art draws (a wisp's body trails behind its origin), upright.
	var art: RisoProp = get_parent().get_node_or_null("RisoArt") as RisoProp if get_parent() != null else null
	ink.global_transform = Transform2D(0.0, art.guard_center() if art != null else global_position)
	ink.begin()
	if hp > 0:
		RisoWard.plates(ink, Vector2.ZERO, RADIUS, full, hp, _spin(), clampf(1.0 - since_hit / 0.18, 0.0, 1.0), RisoPrint.PINK)
	for i: int in range(_broken.size()):
		_broken[i].y += delta
		RisoWard.shards(ink, Vector2.ZERO, RADIUS, _broken[i].x, _broken[i].y / RisoWard.SHARD_TIME, RisoPrint.PINK)
	ink.finish()


## How far the ring has turned: slowly, so it reads as a guard rather than a decoration.
func _spin() -> float:
	return t * SPIN
