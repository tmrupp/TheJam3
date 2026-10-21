extends Node
class_name Lunge
## Lunge, a damage spell: the Spell button (Q, or the pad's X) throws the wizard forward (the way
## held, left or right, else the way they face) at its speed for the knock-back's time
## (Player.knock_back, a quarter of a second: about 160 px at I), halting a fall, and stabs ahead as
## they go: whatever comes within STAB px in front of them, SPAN px up or down (SpellStrike), is
## wounded by its damage, each once a lunge. Ready again COOLDOWN after. So it is a way across as
## well as a blow: a lunge from a jump carries the wizard further. Tiers (Abilities): I wounds 1; II
## lunges further (SPEED_II); III wounds 2; IV a stab that lands makes it ready again at once. Cast
## empowered (Empower), it rams through a cracked wall ahead, up to RAM cells thick (within RAM_LOOK
## cells of the wizard), wounds Empower.EXTRA more, breaks a shield at once and strikes spires.

const COOLDOWN: float = 1.2
## How fast (px/s) it throws the wizard along.
const SPEED: float = 640.0
const SPEED_II: float = 820.0
## How far ahead of the wizard's middle (px) the stab reaches, how far behind it still catches
## (something they lunge into), and how far up or down.
const STAB: float = 60.0
## How many cells of cracked wall an empowered lunge rams through, and how many cells ahead of the
## wizard it looks for the wall.
const RAM: int = 2
const RAM_LOOK: int = 2
const STAB_BACK: float = 10.0
const SPAN: float = 30.0

var damage: int = 1
var speed: float = SPEED
var refunds: bool = false
## Seconds until it is ready again; seconds of the lunge left; the way it goes (-1 or 1).
var wait: float = 0.0
var left: float = 0.0
var side: float = 1.0
## What this lunge has stabbed (each whole thing once), and whether it was cast empowered.
var stabbed: Array[Node] = []
var empowered: bool = false

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): see the class description.
func set_tier(n: int) -> void:
	damage = 2 if n >= 3 else 1
	speed = SPEED_II if n >= 2 else SPEED
	refunds = n >= 4


## The Spell button, with the lunge in the slot (`empowered`, see Empower).
func cast_spell(empowered_cast: bool = false) -> bool:
	return cast(0.0, empowered_cast)


func readiness() -> float:
	return 1.0 - clampf(wait / COOLDOWN, 0.0, 1.0)


## While lunging: (the fraction of it left, seconds left); never otherwise (see Abilities.running).
func running() -> Vector2:
	if left <= 0.0 or player == null:
		return Vector2(-1.0, 0.0)
	return Vector2(left / player.knock_back.MAX_TIME, left)


## Whether a lunge is under way.
func lunging() -> bool:
	return left > 0.0


func _physics_process(delta: float) -> void:
	wait = maxf(0.0, wait - delta)
	if left > 0.0:
		left -= delta
		_stab()


## Lunge `way` (-1 left, 1 right; the held way, else facing, when 0), `empowered_cast` or not. False
## while it is not ready.
func cast(way: float = 0.0, empowered_cast: bool = false) -> bool:
	if wait > 0.0 or player == null:
		return false
	if way == 0.0:
		way = signf(Input.get_axis("Left", "Right"))
	if way == 0.0:
		way = signf(player.sprite.scale.x) if player.sprite != null and player.sprite.scale.x != 0.0 else 1.0
	side = way
	player.knock = Vector2(side * speed, minf(player.velocity.y, 0.0))
	player.knock_back.enable(true)
	left = player.knock_back.MAX_TIME
	stabbed.clear()
	empowered = empowered_cast
	if empowered:
		_ram()
	wait = COOLDOWN
	SpellMark.leave(&"lunge", SpellStrike.origin(player), Vector2(side, 0.0), speed * left, 0.0)
	_stab()
	return true


## Stab ahead: strike what is in front that this lunge has not struck yet.
func _stab() -> void:
	var from: Vector2 = SpellStrike.origin(player)
	var tip: Vector2 = from + Vector2(side * STAB, 0.0)
	var catches: Callable = func(p: Vector2) -> bool:
		var ahead: float = (p.x - from.x) * side
		return ahead >= -STAB_BACK and ahead <= STAB and absf(p.y - from.y) <= SPAN
	var catches_shaped: Callable = func(s: Shaped) -> bool: return s.struck_by(from, tip, 0.0)
	var landed: bool = false
	for e: Node in SpellStrike.caught(get_tree(), from, catches, catches_shaped):
		var whole: Node = Wound.whole(e)
		if whole in stabbed:
			continue
		stabbed.append(whole)
		SpellStrike.strike(e, Vector2(side, 0.0), damage + (Empower.EXTRA if empowered else 0), &"lunge", empowered, from)
		landed = true
	if landed and refunds:
		wait = 0.0


## An empowered lunge's ram: along the wizard's row (and the row of their feet, where that is
## another), the first cracked wall within RAM_LOOK cells ahead crumbles, RAM cells of it at most.
func _ram() -> void:
	var rows: Array[Vector2i] = [SpellStrike.cell_of(SpellStrike.origin(player))]
	var feet: Vector2i = SpellStrike.cell_of(player.global_position + Vector2(0, -8))
	if feet != rows[0]:
		rows.append(feet)
	var step: Vector2i = Vector2i(int(side), 0)
	var info: MapInfo = MapInfo.instance
	for c: Vector2i in rows:
		var wall: Array[Vector2i] = []
		for k: int in range(1, RAM_LOOK + RAM):
			var n: Vector2i = c + step * k
			if CrackedWall.at(get_tree(), n) != null:
				if wall.is_empty() and k > RAM_LOOK:
					break
				wall.append(n)
				if wall.size() >= RAM:
					break
			elif not wall.is_empty() or info == null or info.solid_at(info.cell_position(n)):
				break
		SpellStrike.crack(get_tree(), wall, Vector2(side, 0.0))
