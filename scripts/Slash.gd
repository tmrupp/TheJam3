extends Node
class_name Slash
## Slash, a damage spell: the Spell button (Q, or the pad's X) sweeps an arc of spell light in front
## of the wizard, aimed like the hex (the held direction, else facing), REACH px out and HALF either
## way. It is quick, ready again COOLDOWN after, and everything it catches is struck at once
## (SpellStrike): wounded by its damage. Landing a blow, on an enemy or on thorns, throws the wizard
## back off it (SpellStrike.recoil): a slash down from the air bounces them up. Tiers (Abilities): I
## wounds 1; II reaches further and wider (REACH_II, HALF_II); III wounds 2; IV also cuts shots out
## of the air in its arc. Cast empowered (Empower), it cleaves the cracked rock in its arc and the
## two cells in front of the wizard (cleave_cells), wounds Empower.EXTRA more, breaks a shield at
## once and strikes spires.

## Seconds until it is ready again.
const COOLDOWN: float = 0.7
const REACH: float = 110.0
const HALF: float = 1.05
const REACH_II: float = 140.0
const HALF_II: float = 1.3
## How near (px) the wizard a thing is caught whichever way it lies, as the blade passes them.
const CLOSE: float = 34.0
## How many ways across its arc it feels for a foe with a shape of its own (Shaped).
const RAYS: int = 7
## How much further (px) than its reach an empowered slash cleaves rock (measured to the nearest
## point of a cell), so the cells beside the wizard's are reached wherever in theirs they stand.
const CLEAVE_REACH: float = 64.0

var damage: int = 1
var reach: float = REACH
var half: float = HALF
var cuts_shots: bool = false
## Seconds until it is ready again.
var wait: float = 0.0

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): see the class description.
func set_tier(n: int) -> void:
	damage = 2 if n >= 3 else 1
	reach = REACH_II if n >= 2 else REACH
	half = HALF_II if n >= 2 else HALF
	cuts_shots = n >= 4


## The Spell button, with slash in the slot (`empowered`, see Empower).
func cast_spell(empowered: bool = false) -> bool:
	return cast(Vector2.ZERO, empowered)


func readiness() -> float:
	return 1.0 - clampf(wait / COOLDOWN, 0.0, 1.0)


## A slash is over at once: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	wait = maxf(0.0, wait - delta)


## Whether `p` is in the arc from `from` heading `dir`.
func in_arc(from: Vector2, dir: Vector2, p: Vector2) -> bool:
	var d: Vector2 = p - from
	if d.length() <= CLOSE:
		return true
	return d.length() <= reach and absf(dir.angle_to(d)) <= half


## The cells an empowered slash from `from` heading `dir` cleaves: those about the wizard's whose
## nearest point lies in its arc (CLEAVE_REACH further out), and the two cells in front of them,
## the one beside and the one over it.
func cleave_cells(from: Vector2, dir: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return out
	var c: Vector2i = info.cell_at(from)
	var span: Vector2 = info.cell_position(c + Vector2i.ONE) - info.cell_position(c)
	for dx: int in range(-1, 2):
		for dy: int in range(-2, 2):
			var n: Vector2i = c + Vector2i(dx, dy)
			if n == c:
				continue
			var middle: Vector2 = info.cell_position(n)
			var near: Vector2 = from.clamp(middle - span * 0.5, middle + span * 0.5)
			var d: Vector2 = near - from
			if d.length() <= reach + CLEAVE_REACH and (d.length() <= CLOSE or absf(dir.angle_to(d)) <= half):
				out.append(n)
	if dir.x != 0.0:
		var front: Vector2i = c + Vector2i(int(signf(dir.x)), 0)
		for n: Vector2i in [front, front + Vector2i.UP]:
			if not out.has(n):
				out.append(n)
	return out


## Slash heading `dir` (the aim when zero), `empowered` or not. False while it is not ready.
func cast(dir: Vector2 = Vector2.ZERO, empowered: bool = false) -> bool:
	if wait > 0.0 or player == null:
		return false
	if dir == Vector2.ZERO:
		dir = SpellStrike.aim(player)
	dir = dir.normalized()
	var from: Vector2 = SpellStrike.origin(player)
	var rays: Array[Vector2] = []
	for k: int in range(RAYS):
		rays.append(dir.rotated(lerpf(-half, half, float(k) / float(RAYS - 1))))
	var catches: Callable = func(p: Vector2) -> bool: return in_arc(from, dir, p)
	var catches_shaped: Callable = func(s: Shaped) -> bool:
		return rays.any(func(r: Vector2) -> bool: return s.struck_by(from, from + r * reach, 0.0))
	var struck: Array[Node] = SpellStrike.caught(get_tree(), from, catches, catches_shaped)
	for e: Node in struck:
		SpellStrike.strike(e, ((e as Node2D).global_position - from).normalized(), damage + (Empower.EXTRA if empowered else 0), &"slash", empowered, from)
	if empowered:
		SpellStrike.crack(get_tree(), cleave_cells(from, dir), dir)
	var thorns: Array[Spikes] = SpellStrike.thorns_caught(get_tree(), from, catches, dir)
	if not struck.is_empty() or not thorns.is_empty():
		SpellStrike.recoil(player, dir)
	if cuts_shots and MapInfo.instance != null:
		for n: Node in MapInfo.instance.map_elements.get_children():
			var shot: Node2D = n as Node2D
			if shot is Bullet and not shot.is_queued_for_deletion() and in_arc(from, dir, shot.global_position):
				RisoFx.burst(&"hit", shot.global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
				shot.queue_free()
	SpellMark.leave(&"slash", from, dir, reach, half, RisoPrint.ACCENT, player)
	wait = COOLDOWN
	return true
