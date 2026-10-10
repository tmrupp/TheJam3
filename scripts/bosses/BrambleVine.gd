class_name BrambleVine
extends Node2D
## One of the bramble's thorn vines (Bramble): rooted in a wall of its shaft, it lashes out across
## the shaft and pulls back on a steady cadence, as a laser fires (Laser): it rests in the rock,
## its shoots poke out pink as a warning, it grows out REACH cells, holds there writhing, and pulls
## back. Only while it is out does it hurt (its HitBox, as long as it is). A parry catches its
## lash: it recoils into the rock and stays there while stunned (its Stunner, a parry's stun), then
## rests before it grows again, opening the wall beside it for a while. When the bulb it feeds
## from bursts, it withers for good (wither).

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## Its cadence (seconds): resting in the rock, warning, growing out, holding, pulling back.
const REST: float = 1.4
const WARN: float = 0.8
const GROW: float = 0.25
const HOLD: float = 1.1
const PULL: float = 0.45
const PERIOD: float = REST + WARN + GROW + HOLD + PULL
## How far it reaches out of the wall at full length (cells; the shaft is BrambleShaft.WIDTH wide,
## so the far side stays clear), and how thick its touch is (px).
const REACH: float = 2.5
const THICK: float = 40.0
## Shorter than this (px) it does not hurt.
const TOUCH_MIN: float = 20.0
## How fast it whips back into the rock, parried or withering (its full length a second, times).
const RECOIL_RATE: float = 5.0
## Salt for the level seed: how far through its cadence it starts, so vines are out of step.
const PHASE_DEAL: int = 6650

## The bramble it belongs to, its wall cell, the way out of the rock, and the bulb it feeds from.
var bramble: Bramble
var cell: Vector2i = Vector2i.ZERO
var way: Vector2 = Vector2.RIGHT
var bulb: BrambleBulb
## Its clock through the cadence, how long it is now (px), and at full length.
var t: float = 0.0
var length: float = 0.0
var full: float = 160.0
var withered: bool = false
var hit_box: HitBox
var stunner: Stunner
var _box: RectangleShape2D = RectangleShape2D.new()


func _init(of: Bramble, wall: Vector2i, out: Vector2) -> void:
	bramble = of
	cell = wall
	way = out
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	add_child(stunner)
	hit_box = HIT_BOX.instantiate() as HitBox
	hit_box.name = "HitBox"
	hit_box.rotation = out.angle()
	add_child(hit_box)
	# Its own shape: the prefab's is shared by every hit box.
	(hit_box.get_node("CollisionShape2D") as CollisionShape2D).shape = _box
	_box.size = Vector2(1.0, THICK)


## Root it at the face of its wall cell (cells `cell_px` across), part way through its cadence.
func place(face: Vector2, cell_px: float, level_seed: int) -> void:
	global_position = face
	full = REACH * cell_px
	t = RisoDecor.h(level_seed, cell, PHASE_DEAL) * PERIOD


## Where it is in its cadence: &"rest", &"warn", &"grow", &"hold" or &"pull", and how far through
## it (0 to 1).
func phase() -> Array:
	var u: float = fposmod(t, PERIOD)
	for part: Array in [[&"rest", REST], [&"warn", WARN], [&"grow", GROW], [&"hold", HOLD]]:
		if u < float(part[1]):
			return [part[0], u / float(part[1])]
		u -= float(part[1])
	return [&"pull", clampf(u / PULL, 0.0, 1.0)]


## How long it would be now, by its cadence alone.
func _target() -> float:
	var state: Array = phase()
	var u: float = state[1]
	match state[0]:
		&"grow":
			return full * (1.0 - (1.0 - u) * (1.0 - u))
		&"hold":
			return full
		&"pull":
			return full * (1.0 - u * u)
	return 0.0


## Whether it is recoiled into the rock from a parry.
func recoiled() -> bool:
	return stunner.stunned()


## Whether it is out far enough to hurt.
func hurts() -> bool:
	return not withered and not recoiled() and length >= TOUCH_MIN


## Its bulb has burst (or the bramble has died): it shrinks into the rock for good.
func wither() -> void:
	withered = true


func _physics_process(delta: float) -> void:
	if withered or recoiled():
		# Parried, its cadence starts again from rest once the stun is over.
		if not withered:
			t = 0.0
		length = move_toward(length, 0.0, full * RECOIL_RATE * delta)
	else:
		# A harder preset runs its cadence faster (Difficulty.haste).
		t += delta * Difficulty.haste()
		length = _target()
	_box.size = Vector2(maxf(length, 1.0), THICK)
	(hit_box.get_node("CollisionShape2D") as CollisionShape2D).position = Vector2(length * 0.5, 0.0)
	# Its Stunner turns the touch back on when a stun ends, so this is checked every frame.
	var off: bool = not hurts()
	if hit_box.collision != null and hit_box.collision.disabled != off:
		hit_box.collision.set_deferred("disabled", off)
