extends Node2D
class_name Slime
## The trail an abomination leaves as it drags itself along the floor (Abomination): smears of pink
## slime laid every GAP px it crawls, each fading out over LIFE seconds. While a smear is fresh
## (younger than HURT_FOR seconds) it hurts the wizard standing in it, as thorns do: a hazard, with
## nothing behind it for a parry to strike. It is its own node in the level, so a trail outlasts
## the abomination that left it, and it goes once its abomination is gone and its last smear has
## faded. Nothing here draws from any RNG.

## How far apart smears are laid (px), how long each lasts and how long it hurts (seconds), how
## wide and thick a smear is (px), how near the wizard's feet must be to one to be hurt (px across
## and up), and how hard it throws them (px/s up).
const GAP: float = 18.0
const LIFE: float = 2.2
const HURT_FOR: float = 1.4
const SIZE: Vector2 = Vector2(30.0, 7.0)
const REACH: Vector2 = Vector2(22.0, 24.0)
const KNOCK: float = 260.0
## How far under the wizard's middle their feet are (px).
const FEET: float = 30.0

## The smears: x, y where each lies on the floor, z its age (seconds), w its size (0.6 to 1.2).
var smears: Array[Vector4] = []
## The abomination laying it (null once it is gone).
var source: Node2D = null
var ink: InkCanvas


func _ready() -> void:
	z_index = 1
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	ink.top_level = true
	ink.z_as_relative = false
	ink.z_index = 1
	add_child(ink)


## A smear at `at` (the floor under its abomination), sized `size`.
func lay(at: Vector2, size: float) -> void:
	smears.append(Vector4(at.x, at.y, 0.0, size))


## Whether a fresh smear lies under world point `feet`.
func fresh_at(feet: Vector2) -> bool:
	for s: Vector4 in smears:
		if s.z < HURT_FOR and absf(feet.x - s.x) <= REACH.x * s.w and feet.y >= s.y - REACH.y and feet.y <= s.y + 8.0:
			return true
	return false


func _physics_process(delta: float) -> void:
	for i: int in range(smears.size() - 1, -1, -1):
		var s: Vector4 = smears[i]
		s.z += delta
		if s.z >= LIFE:
			smears.remove_at(i)
		else:
			smears[i] = s
	var gone: bool = source == null or not is_instance_valid(source) or source.is_queued_for_deletion()
	if gone and smears.is_empty():
		queue_free()
		return
	var player: Player = Stage.player()
	if player != null and is_instance_valid(player) and player.is_on_floor() and fresh_at(player.global_position + Vector2(0, FEET)):
		player.hurt(-1, Vector2(0, -KNOCK), self)


func _process(_delta: float) -> void:
	ink.begin()
	var wet: Array[PackedVector2Array] = []
	var faint: Array[PackedVector2Array] = []
	for s: Vector4 in smears:
		var u: float = s.z / LIFE
		var c: Vector2 = Vector2(s.x, s.y - 2.0)
		var smear: PackedVector2Array = RisoShapes.ellipse(c, SIZE.x * s.w * (1.0 - 0.2 * u), SIZE.y * s.w * (1.0 - 0.5 * u), 14)
		if s.z < HURT_FOR:
			wet.append(smear)
		else:
			faint.append(smear)
	# Fresh slime is solid danger pink with a wet paper glint; it thins to a faint stain as it dries.
	ink.ink(RisoPrint.PINK, 0.85, wet)
	ink.ink(RisoPrint.PINK, 0.35, faint)
	var glints: Array[PackedVector2Array] = []
	for s: Vector4 in smears:
		if s.z < HURT_FOR * 0.6:
			glints.append(RisoShapes.ellipse(Vector2(s.x - 6.0 * s.w, s.y - 4.0), 4.0 * s.w, 1.2, 8))
	ink.knock([RisoPrint.PINK, RisoPrint.NIGHT, RisoPrint.BLUE], glints)
	ink.finish()
