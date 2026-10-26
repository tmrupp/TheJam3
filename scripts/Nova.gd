extends Node
class_name Nova
## Nova, a damage spell: the Spell button (Q, or the pad's X) bursts spell light out all round the
## wizard, RADIUS px, striking everything it reaches that rock does not shelter (SpellStrike):
## wounded by its damage. It is slower to come back than a slash (COOLDOWN). Tiers (Abilities): I
## wounds 1; II reaches further (RADIUS_II); III wounds 2; IV comes back sooner (COOLDOWN_IV). Cast
## empowered (Empower), it shatters the cracked rock in a ring round the wizard, a cell out
## (SpellStrike.ring), wounds Empower.EXTRA more, breaks a shield at once and strikes spires.

## Seconds until it is ready again, and from tier IV.
const COOLDOWN: float = 3.0
const COOLDOWN_IV: float = 2.0
const RADIUS: float = 170.0
const RADIUS_II: float = 220.0

var damage: int = 1
var radius: float = RADIUS
var cooldown: float = COOLDOWN
## Seconds until it is ready again.
var wait: float = 0.0

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): see the class description.
func set_tier(n: int) -> void:
	damage = 2 if n >= 3 else 1
	radius = RADIUS_II if n >= 2 else RADIUS
	cooldown = COOLDOWN_IV if n >= 4 else COOLDOWN
	wait = minf(wait, cooldown)


## The Spell button, with nova in the slot (`empowered`, see Empower).
func cast_spell(empowered: bool = false) -> bool:
	return cast(empowered)


func readiness() -> float:
	return 1.0 - clampf(wait / cooldown, 0.0, 1.0)


## A burst is over at once: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	wait = maxf(0.0, wait - delta)


## Burst, `empowered` or not. False while it is not ready.
func cast(empowered: bool = false) -> bool:
	if wait > 0.0 or player == null:
		return false
	var from: Vector2 = SpellStrike.origin(player)
	var catches: Callable = func(p: Vector2) -> bool: return p.distance_to(from) <= radius
	var catches_shaped: Callable = func(s: Shaped) -> bool: return s.struck_by(from, from, radius) and SpellStrike.clear(from, s.global_position)
	for e: Node in SpellStrike.caught(get_tree(), from, catches, catches_shaped):
		var away: Vector2 = ((e as Node2D).global_position - from)
		SpellStrike.strike(e, away.normalized() if away != Vector2.ZERO else Vector2.UP, damage + (Empower.EXTRA if empowered else 0), &"nova", empowered, from)
	if empowered:
		var c: Vector2i = SpellStrike.cell_of(from)
		for n: Vector2i in SpellStrike.ring(c):
			SpellStrike.crack(get_tree(), [n], Vector2(n - c).normalized())
	SpellMark.leave(&"nova", from, Vector2.RIGHT, radius, PI, RisoPrint.ACCENT, player)
	wait = cooldown
	Wound.shake(6.0, 0.15)
	return true
