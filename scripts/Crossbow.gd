class_name Crossbow
extends Node2D
## A crossbow built into a crag tower's or keep's wall (CragsArchetype.place_crossbows,
## place_keep_crossbows): a block of the wall's
## own stone, solid as the rest of it, with the crossbow set in a niche on its inner face and a bore
## through to an arrow slit on its outer face. It shoots dead straight out of the slit, level: while
## it sees the wizard in front of it (on its side, within RANGE cells, no more than LINE above or
## below its slit, with a clear line from it), it winds back its string over DRAW seconds in sight,
## and looses; the moment it loses sight the draw starts again. The first arrow at a wizard who has
## been out of its sight for REST seconds is drawn far quicker (FIRST_DRAW: it was waiting, ready),
## and after a shot it reloads for RELOAD seconds (in sight or not) before it can draw again, so
## the first shot comes almost at once and the rest more slowly. Its arrows wound any enemy in their way, too (Bullet). From outside it is a cell of stone away: bolts and
## dashes stop at the wall short of it, and a parried arrow flies back only as far as the wall.
## From the room inside it is right at the wall's face, an enemy like any (its Wound, given as it
## is placed): any hex bolt or dash wounds it, even one of no damage (Wound.least), and once
## broken the level record keeps it so until the wizard dies, the wall left whole. Its cell in the
## level is the room cell before the wall; the node sits in the wall. Nothing here draws from the
## world RNG.
## One set in the spider's keep (SpiderKeep.arm, `inward`) shoots into the hall instead: its cell is
## the hall's cell in front of its slit, and it sits in the wall behind that, with stone, not a
## room, behind it, so nothing reaches it to break it. Its arrows pierce the spider (Bullet).

## How far it sees (cells), how far above or below its slit the wizard may be for it to shoot
## (pixels), how long it takes to draw and loose (seconds in sight), how long it reloads after a
## shot (seconds), and how fast its arrows fly (pixels a second).
const RANGE: int = 9
const LINE: float = 80.0
const DRAW: float = 0.8
const RELOAD: float = 1.6
## How long it draws its first arrow at a wizard just come into sight (seconds in sight), and how
## long the wizard must be out of its sight (seconds) for the next arrow to count as a first again.
const FIRST_DRAW: float = 0.2
const REST: float = 2.5
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
## Whether it sees the wizard this frame, seconds since it last loosed (for the art's kick), and
## seconds of reloading left.
var sees: bool = false
var since_shot: float = 99.0
## Seconds since it last saw the wizard (while loaded and waiting, it counts toward a quick first
## arrow, REST), and whether the arrow it draws now is such a first.
var unseen: float = 99.0
var first: bool = true
var reload_left: float = 0.0
## Where it sits in the wall (world pixels); a wound's knock does not move it.
var anchor: Vector2 = Vector2.ZERO
## A level cell's size, in world pixels.
var cell_px: float = 128.0

@onready var _sfx: AudioStreamPlayer = $AudioStreamPlayer


## For room cell `v`, as `extra` says: {"facing": +1 right or -1 left}: set into the wall beside it
## that way; or, with "inward" (the spider's keep), into the wall behind the hall's cell `v`,
## shooting out over it that way.
func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	map_info = info
	cell = v
	var how: Dictionary = extra if extra is Dictionary else {}
	facing = -1 if int(how.get("facing", 1)) < 0 else 1
	var tm: TileMap = info.tile_map
	cell_px = float(tm.tile_set.tile_size.y) * tm.global_scale.y
	anchor = global_position + Vector2(float(facing) * (cell_px * 0.5 + DEPTH), 0.0)
	if bool(how.get("inward", false)):
		anchor = global_position - Vector2(float(facing) * (cell_px * 1.5 - DEPTH), 0.0)
	global_position = anchor
	# Wounded by any bolt or dash, even one of no damage: it has nothing to stun.
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.least = 1


## Where its arrows leave the wall: just outside the wall's outer face, at its own height.
func muzzle() -> Vector2:
	return anchor + Vector2(float(facing) * (cell_px - DEPTH + LOOSE_OUT), 0.0)


## Whether it is loaded, a bolt laid on its string, ready to draw.
func loaded() -> bool:
	return reload_left <= 0.0


## Whether it sees the wizard: outside, on its side, in range, in line with its slit, with nothing
## between.
func can_see() -> bool:
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player):
		return false
	var from: Vector2 = muzzle()
	var d: Vector2 = player.global_position - from
	if signf(d.x) != float(facing) or d.length() > float(RANGE) * cell_px:
		return false
	if absf(d.y) > LINE:
		return false
	# Only the wizard (layer 1) and the environment (layer 3) block its view, as a watcher's.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, player.global_position, 1 | 4)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


func _physics_process(delta: float) -> void:
	global_position = anchor
	since_shot += delta
	# A harder preset draws and reloads sooner (Difficulty.attack).
	reload_left = maxf(0.0, reload_left - delta * Difficulty.attack())
	sees = can_see()
	unseen = 0.0 if sees else unseen + delta
	if unseen >= REST:
		first = true
	if not sees or not loaded():
		drawn = 0.0
		return
	drawn += delta * Difficulty.attack() / (FIRST_DRAW if first else DRAW)
	if drawn >= 1.0:
		drawn = 0.0
		loose()


## An arrow, straight out through the slit; then it reloads.
func loose() -> void:
	if map_info == null:
		return
	var arrow: Bullet = ARROW.instantiate() as Bullet
	arrow.arrow = true
	map_info.map_elements.add_child(arrow)
	arrow.global_position = muzzle()
	arrow.setup(Vector2(float(facing) * ARROW_SPEED, 0.0), [self], self)
	since_shot = 0.0
	reload_left = RELOAD
	first = false
	_sfx.play()
