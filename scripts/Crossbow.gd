class_name Crossbow
extends Node2D
## A crossbow built into a crag tower's or keep's wall (CragsArchetype.place_crossbows,
## place_keep_crossbows): a block of the wall's
## own stone, solid as the rest of it, with the crossbow set in a niche on its inner face and a bore
## through to an arrow slit on its outer face. While it sees the wizard outside on its side (within
## RANGE cells, no more than AIM off level, with a clear line from the slit), it winds back its
## string, the bore glowing pink, and looses an arrow at them every DRAW seconds in sight; the
## moment it loses sight the draw starts again. From outside it is a cell of stone away: bolts and
## dashes stop at the wall short of it, and a parried arrow flies back only as far as the wall.
## From the room inside it is right at the wall's face, an enemy like any (its Wound, given as it
## is placed): any hex bolt or dash wounds it, even one that only stuns (Wound.least), and once
## broken the level record keeps it so until the wizard dies, the wall left whole. Its cell in the
## level is the room cell before the wall; the node sits in the wall. Nothing here draws from the
## world RNG.

## How far it sees (cells), how far off level it can aim (radians either way), how long it takes
## to draw and loose (seconds in sight), and how fast its arrows fly (pixels a second).
const RANGE: int = 9
const AIM: float = 0.9
const DRAW: float = 2.4
const ARROW_SPEED: float = 620.0
## How deep in the wall it sits, from the wall's inner face (pixels): within reach of a bolt or a
## dash from the room, a cell of stone from one outside.
const DEPTH: float = 22.0
## How far past the wall's outer face an arrow is loosed (pixels), clear of the stone.
const LOOSE_OUT: float = 14.0
const ARROW: PackedScene = preload("res://prefabs/bullet.tscn")

var map_info: MapInfo
## Its room cell, and the way it shoots: +1 out through the wall on the room's right, -1 its left.
var cell: Vector2i = Vector2i.ZERO
var facing: int = 1
## 0..1: how far it has drawn toward the next arrow (the art winds its string back).
var drawn: float = 0.0
## Whether it sees the wizard this frame, and seconds since it last loosed (for the art's kick).
var sees: bool = false
var since_shot: float = 99.0
## Where it sits in the wall (world pixels); a wound's knock does not move it.
var anchor: Vector2 = Vector2.ZERO
## A level cell's size, in world pixels.
var cell_px: float = 128.0

@onready var _sfx: AudioStreamPlayer = $AudioStreamPlayer


## For room cell `v`, as `extra` says: {"facing": +1 right or -1 left}: set into the wall beside it
## that way.
func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	map_info = info
	cell = v
	var how: Dictionary = extra if extra is Dictionary else {}
	facing = -1 if int(how.get("facing", 1)) < 0 else 1
	var tm: TileMap = info.tile_map
	cell_px = float(tm.tile_set.tile_size.y) * tm.global_scale.y
	anchor = global_position + Vector2(float(facing) * (cell_px * 0.5 + DEPTH), 0.0)
	global_position = anchor
	# Wounded by any bolt or dash, even one that only stuns: it has nothing to stun.
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.least = 1


## Where its arrows leave the wall: just outside the wall's outer face, at its own height.
func muzzle() -> Vector2:
	return anchor + Vector2(float(facing) * (cell_px - DEPTH + LOOSE_OUT), 0.0)


## Whether it sees the wizard: outside, on its side, in range, within its aim, with nothing between.
func can_see() -> bool:
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player):
		return false
	var from: Vector2 = muzzle()
	var d: Vector2 = player.global_position - from
	if signf(d.x) != float(facing) or d.length() > float(RANGE) * cell_px:
		return false
	if absf(atan2(d.y, absf(d.x))) > AIM:
		return false
	# Only the wizard (layer 1) and the environment (layer 3) block its view, as a watcher's.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, player.global_position, 1 | 4)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


func _physics_process(delta: float) -> void:
	global_position = anchor
	since_shot += delta
	sees = can_see()
	if not sees:
		drawn = 0.0
		return
	# A harder preset looses more often (Difficulty.attack).
	drawn += delta * Difficulty.attack() / DRAW
	if drawn >= 1.0:
		drawn = 0.0
		loose()


## An arrow, out through the slit at the wizard.
func loose() -> void:
	var player: Player = Stage.player()
	if player == null or map_info == null:
		return
	var from: Vector2 = muzzle()
	var arrow: Bullet = ARROW.instantiate() as Bullet
	arrow.arrow = true
	map_info.map_elements.add_child(arrow)
	arrow.global_position = from
	arrow.setup((player.global_position - from).normalized() * ARROW_SPEED, [self], self)
	since_shot = 0.0
	_sfx.play()
