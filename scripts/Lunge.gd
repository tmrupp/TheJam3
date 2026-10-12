extends Node
class_name Lunge
## Lunge, a damage spell: the Spell button (Q, or the pad's X) throws the wizard forward (the way
## held, left or right, else the way they face) at its speed for the knock-back's time
## (Player.knock_back, a quarter of a second: about 160 px at I), halting a fall, and stabs ahead
## as they go: whatever comes within STAB px in front of them, SPAN px up or down (SpellStrike), is
## wounded by its damage and stunned STUN seconds, each once a lunge. It tears the spider's webs it
## stabs through. Ready again COOLDOWN after. So it is a way across as well as a blow: a lunge from
## a jump carries the wizard further. Tiers (Abilities): I wounds 1; II lunges further (SPEED_II);
## III wounds 2; IV a stab that lands makes it ready again at once.

const COOLDOWN: float = 1.2
const STUN: float = 1.0
## How fast (px/s) it throws the wizard along.
const SPEED: float = 640.0
const SPEED_II: float = 820.0
## How far ahead of the wizard's middle (px) the stab reaches, how far behind it still catches
## (something they lunge into), and how far up or down.
const STAB: float = 60.0
const STAB_BACK: float = 10.0
const SPAN: float = 30.0

var damage: int = 1
var speed: float = SPEED
var refunds: bool = false
## Seconds until it is ready again; seconds of the lunge left; the way it goes (-1 or 1).
var wait: float = 0.0
var left: float = 0.0
var side: float = 1.0
## What this lunge has stabbed (each whole thing once).
var stabbed: Array[Node] = []

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): see the class description.
func set_tier(n: int) -> void:
	damage = 2 if n >= 3 else 1
	speed = SPEED_II if n >= 2 else SPEED
	refunds = n >= 4


## The Spell button, with the lunge in the slot.
func cast_spell() -> bool:
	return cast()


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


## Lunge `way` (-1 left, 1 right; the held way, else facing, when 0). False while it is not ready.
func cast(way: float = 0.0) -> bool:
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
	var catches_spider: Callable = func(s: Spider) -> bool: return s.struck_by(from, tip, 0.0)
	var landed: bool = false
	for e: Node in SpellStrike.caught(get_tree(), from, catches, catches_spider):
		var whole: Node = Wound.whole(e)
		if whole in stabbed:
			continue
		stabbed.append(whole)
		SpellStrike.strike(e, Vector2(side, 0.0), damage, STUN)
		landed = true
	SpiderWeb.tear_along(get_tree(), from, tip)
	if landed and refunds:
		wait = 0.0
