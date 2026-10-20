class_name Wreck
extends AnimatableBody2D
## Wreckage the whale has swallowed (Belly): a ledge WIDE cells across lying in a pit of its
## stomach's floor, one-way and rideable like any ledge (a lift's collision layer, so dropping
## through works too). It floats on the acid (Acid): while the acid lies below it, it rests on the
## pit's floor; as the acid floods it rides up on its surface, bobbing, its deck DRAFT over it, and
## as it drains it settles back. Ridden up, it keeps the wizard out of the flood. What it was is its
## kind (KINDS, given with the level): a balloon's basket, a temple's column drum lying on its side,
## or a crate. Printed by its own art (WreckArt). Nothing here draws from any RNG.

## The kinds it can be.
const KINDS: Array[StringName] = [&"basket", &"column", &"crate"]
## Its cells across, how tall it stands from the pit's floor to its deck (px), how high its deck
## rides over the acid (px), and how far it bobs there (px).
const WIDE: int = 2
const TALL: float = 72.0
const DRAFT: float = 40.0
const BOB: float = 5.0
## How thick its deck's collision is (px), as a ledge's is.
const DECK: float = 33.0

## What it was (KINDS).
var kind: StringName = &"crate"
## Its deck's height lying on the pit's floor (world y), and its middle across (world x).
var rest_y: float = 0.0
var mid_x: float = 0.0
## The acid it floats on, if any; its clock (for the bob) and a phase of its own.
var acid: Acid = null
var t: float = 0.0
var phase: float = 0.0


## `extra` is its kind (KINDS). `v` is its left cell, on the pit's floor.
func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	kind = StringName(extra) if extra != null and KINDS.has(StringName(extra)) else &"crate"
	var cell: Vector2 = info.cell_position(Vector2i(1, 1)) - info.cell_position(Vector2i.ZERO)
	var at: Vector2 = info.cell_position(v)
	mid_x = at.x + cell.x * float(WIDE - 1) * 0.5
	rest_y = at.y + cell.y * 0.5 - TALL
	phase = RisoDecor.h(info.world.seed_for_colors, v, 9950) * TAU
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(float(WIDE) * cell.x - 12.0, DECK)
	var col: CollisionShape2D = $CollisionShape2D
	col.shape = shape
	col.position = Vector2(0.0, DECK * 0.5)
	_place(Vector2(mid_x, rest_y))


## Teleport without sweeping: physics sync is off for the move, so nothing is pushed along the way.
func _place(at: Vector2) -> void:
	sync_to_physics = false
	global_position = at
	sync_to_physics = true


## Whether it is afloat (the acid over the floor it rests on).
func afloat() -> bool:
	return acid != null and acid.surface() - DRAFT < rest_y


## Where its deck is now (world y): resting, or riding the acid, bobbing.
func deck_y() -> float:
	if acid == null:
		return rest_y
	var riding: float = acid.surface() - DRAFT
	if riding >= rest_y:
		return rest_y
	# It lifts off its floor gently, and bobs only once it is well afloat.
	var lift: float = clampf((rest_y - riding) / 40.0, 0.0, 1.0)
	return riding + sin(t * 1.8 + phase) * BOB * lift


func _physics_process(delta: float) -> void:
	t += delta
	if acid == null or not is_instance_valid(acid):
		acid = Acid.under(get_tree(), mid_x)
	global_position = Vector2(mid_x, deck_y())
