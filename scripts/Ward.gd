extends Node2D
class_name Ward
## The ward, a perk: a ring of plates of the wizard's light round them (RisoWard) that takes a hit
## for them. A hit that would wound them breaks a charge instead (Player.normal_hurt): no heart is
## lost, the wizard is still knocked back and is untouchable for SAFE, and the plates fly apart.
## A broken charge grows back after `recharge` seconds clear of hits; its plates print faintly as
## they grow. A parry is tried first, so a caught hit never touches the ward. Tiers (Abilities):
## I one charge back in RECHARGE seconds, II back in RECHARGE_II, III a second charge.

## Plates printed for each charge, and the ring's radius, centre over the wizard's feet and turn.
const PLATES: int = 3
const RADIUS: float = 72.0
const CENTER: Vector2 = Vector2(0, -24)
const SPIN: float = 0.8
## How strongly the ring prints round the wizard (it flares fully when struck): faint, so it never
## competes with the figure; and how thick its plates are.
const COVER: float = 0.35
const THICK: float = 6.0
## Seconds a broken charge takes to grow back: tier I, and from tier II.
const RECHARGE: float = 12.0
const RECHARGE_II: float = 7.0
## How long a hit the ward takes leaves the wizard untouchable.
const SAFE: float = 1.0

var charges_max: int = 0
var charges: int = 0
var recharge: float = RECHARGE
## Seconds towards the next charge growing back (restarts with every hit taken).
var regrowing: float = 0.0
var since_hit: float = 99.0
var t: float = 0.0
## The plates broken so far: [the angle each broke at, seconds since], while their shards fly.
var _broken: Array[Vector2] = []


## Its tier (Abilities): I one charge, back in RECHARGE seconds; II back in RECHARGE_II; III two
## charges. Learning a tier fills it.
func set_tier(n: int) -> void:
	charges_max = 2 if n >= 3 else (1 if n >= 1 else 0)
	recharge = RECHARGE_II if n >= 2 else RECHARGE
	charges = charges_max
	regrowing = 0.0


## A hit came (knocking the wizard along `v`): with a charge left, it breaks instead, and true
## comes back.
func take(v: Vector2) -> bool:
	if charges <= 0:
		return false
	charges -= 1
	regrowing = 0.0
	since_hit = 0.0
	for i: int in range(charges * PLATES, (charges + 1) * PLATES):
		_broken.append(Vector2(RisoWard.plate_angle(i, charges_max * PLATES, t * SPIN), 0.0))
	var at: Vector2 = global_position + CENTER
	RisoFx.burst(&"gain", at, v.normalized(), [RisoPrint.GLOW, RisoPrint.EYE])
	Wound.shake(6.0, 0.14)
	return true


## How far the next charge has grown back, 0 to 1 (0 when full).
func regrowth() -> float:
	if charges >= charges_max or recharge <= 0.0:
		return 0.0
	return clampf(regrowing / recharge, 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	since_hit += delta
	if charges < charges_max:
		regrowing += delta
		if regrowing >= recharge:
			charges += 1
			regrowing = 0.0
			RisoFx.burst(&"gain", global_position + CENTER, Vector2.UP, [RisoPrint.GLOW, RisoPrint.EYE])
	for i: int in range(_broken.size()):
		_broken[i].y += delta


## Prints the ring round `at` (world position) into `ink`, the wizard's world canvas
## (RisoWizard._draw_world), in eye-yellow, the wizard's own light (as the parry's gleam).
func print_ring(ink: InkCanvas, at: Vector2) -> void:
	if charges_max > 0:
		RisoWard.plates(ink, at, RADIUS, charges_max * PLATES, charges * PLATES, t * SPIN, clampf(1.0 - since_hit / 0.18, 0.0, 1.0), RisoPrint.EYE, regrowth(), PLATES, COVER, THICK)
	for b: Vector2 in _broken:
		RisoWard.shards(ink, at, RADIUS, b.x, b.y / RisoWard.SHARD_TIME, RisoPrint.EYE)
