class_name Whale
extends Node2D
## The whale (Bosses.UP's last, docs/REGIONS_PLAN.md §6) in the level it is in now (WhaleHunt: one
## world on the sky's top row, moving as the wizard comes and goes), put there as the level is
## built (MapInfo._spawn_whale). A great slow body LENGTH long, high in the level. Outside it cannot
## be wounded: bolts and dashes pass it by. Free, it swims from one side of the level to the other
## and back (SWIM px/s), its mouth shut. Trapped (WhaleHunt.trapped: the levels either side set to
## blow into its level) it can go nowhere: it holds near the middle, turning slowly, and opens its
## mouth for MOUTH_OPEN seconds of every MOUTH_EVERY; touched while open, its mouth takes the wizard
## into its belly (Belly, MapInfo.enter_belly), where its heart is. Printed by itself: a dark body,
## paler grooved belly, a sun eye, its flukes beating; its open mouth pink inside. Nothing here
## draws from any RNG.

## Its length, its body's half-height (px), and how high in the level it swims (rows from the top).
const LENGTH: float = 900.0
const GIRTH: float = 150.0
const SWIM_ROW: int = 6
## How fast it swims when free (px/s), and how far it holds from the middle when trapped (px).
const SWIM: float = 160.0
const HOLD: float = 120.0
## Its mouth, trapped: open MOUTH_OPEN seconds of every MOUTH_EVERY, and how near (px) its mouth's
## middle the wizard must come to be taken in.
const MOUTH_EVERY: float = 6.0
const MOUTH_OPEN: float = 2.5
const MOUTH_REACH: float = 110.0

var map_info: MapInfo
## Whether it is trapped in this level, which way it faces (+1 right), its clock, and how far its
## mouth is open (0 shut, 1 wide).
var trapped: bool = false
var facing: float = 1.0
var t: float = 0.0
var gape: float = 0.0
## The level's span across (px) it swims within, and the height it swims at.
var left_x: float = 0.0
var right_x: float = 0.0
var swim_y: float = 0.0
var ink: InkCanvas


func setup(info: MapInfo) -> void:
	map_info = info
	trapped = WhaleHunt.trapped(info.run, info.coord.x)
	var w: LevelGen = info.world
	left_x = info.cell_position(Vector2i(0, 0)).x + LENGTH * 0.5
	right_x = info.cell_position(Vector2i(w.size.x - 1, 0)).x - LENGTH * 0.5
	swim_y = info.cell_position(Vector2i(0, SWIM_ROW)).y
	global_position = Vector2((left_x + right_x) * 0.5, swim_y)


func _ready() -> void:
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


## Where its mouth's middle is.
func mouth() -> Vector2:
	return global_position + Vector2(facing * LENGTH * 0.47, GIRTH * 0.25)


## Whether its mouth is open (trapped, in the open part of its cycle).
func open() -> bool:
	return trapped and fposmod(t, MOUTH_EVERY) >= MOUTH_EVERY - MOUTH_OPEN


func _physics_process(delta: float) -> void:
	if map_info == null:
		return
	t += delta
	var middle: float = (left_x + right_x) * 0.5
	if trapped:
		global_position.x = middle + sin(t * 0.25) * HOLD
		facing = 1.0 if cos(t * 0.25) >= 0.0 else -1.0
	else:
		global_position.x += facing * SWIM * delta
		if global_position.x > right_x:
			facing = -1.0
		elif global_position.x < left_x:
			facing = 1.0
	global_position.y = swim_y + sin(t * 0.6) * 24.0
	gape = move_toward(gape, 1.0 if open() else 0.0, delta * 3.0)
	var player: Player = Stage.player()
	if open() and gape > 0.6 and player != null and is_instance_valid(player) and not map_info.travelling:
		if player.global_position.distance_to(mouth()) <= MOUTH_REACH:
			map_info.enter_belly()


func _process(_delta: float) -> void:
	if ink == null:
		return
	ink.global_transform = Transform2D(0.0, global_position) * Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2.ZERO)
	ink.begin()
	var l: float = LENGTH * 0.5
	var h: float = GIRTH
	# Its body: round at the head, tapering to the tail stock.
	var body: PackedVector2Array = PackedVector2Array()
	for i: int in range(40):
		var a: float = TAU * float(i) / 40.0
		var x: float = cos(a) * l
		var taper: float = 1.0 - 0.75 * clampf(-x / l, 0.0, 1.0) * clampf(-x / l, 0.0, 1.0)
		body.append(Vector2(x, sin(a) * h * taper + (h * 0.15 if x > 0.0 else 0.0)))
	# Its flukes, beating.
	var beat: float = sin(t * 1.6) * 0.35
	var stock: Vector2 = Vector2(-l * 0.98, 0.0)
	var fluke: Transform2D = Transform2D(beat, stock)
	var flukes: PackedVector2Array = fluke * PackedVector2Array([Vector2(0, -8), Vector2(-150, -90), Vector2(-110, 0), Vector2(-150, 90), Vector2(0, 8)])
	# A fin under its middle.
	var fin: PackedVector2Array = Transform2D(0.4 + beat * 0.3, Vector2(l * 0.25, h * 0.7)) * PackedVector2Array([Vector2(0, -10), Vector2(-120, 50), Vector2(-60, 10)])
	var dark: Array[PackedVector2Array] = [body, flukes, fin]
	ink.knock([RisoPrint.BLUE], dark)
	ink.ink(RisoPrint.NIGHT, 0.95, dark, false)
	# Its paler belly, grooved.
	var belly: PackedVector2Array = PackedVector2Array()
	for i: int in range(21):
		var u: float = float(i) / 20.0
		var x: float = lerpf(l * 0.95, -l * 0.3, u)
		belly.append(Vector2(x, h * (0.25 + 0.75 * sin(u * PI)) * 0.85))
	for i: int in range(20, -1, -1):
		var u: float = float(i) / 20.0
		belly.append(Vector2(lerpf(l * 0.95, -l * 0.3, u), h * 0.9 * (1.0 - 0.3 * u)))
	ink.lift_ink([RisoPrint.NIGHT], 0.45, [belly])
	var grooves: Array[PackedVector2Array] = []
	for k: int in range(6):
		var y: float = h * (0.45 + float(k) * 0.08)
		grooves.append(RisoShapes.rrect(-l * 0.1, y, l * (0.95 - float(k) * 0.08), 2.5, 1.0))
	ink.ink(RisoPrint.NIGHT, 0.4, grooves, false)
	# Its mouth: a seam along its head, or gaping pink inside.
	var lip: Vector2 = Vector2(l * 0.95, h * 0.25)
	if gape > 0.02:
		var maw: PackedVector2Array = PackedVector2Array([lip + Vector2(-l * 0.45, 0.0), lip + Vector2(10.0, -h * 0.55 * gape), lip + Vector2(30.0, h * 0.05), lip + Vector2(10.0, h * 0.6 * gape)])
		ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [maw])
		ink.ink(RisoPrint.PINK, 0.9, [maw])
	else:
		ink.lift_ink([RisoPrint.NIGHT], 0.5, [RisoShapes.rrect(lip.x - l * 0.45, lip.y - 2.0, l * 0.45, 4.0, 2.0)])
	# Its eye, in sun.
	var eye: Vector2 = Vector2(l * 0.62, -h * 0.05)
	ink.knock([RisoPrint.NIGHT], [RisoShapes.circle(eye, 14.0, 16)])
	ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(eye, 9.0, 14)])
	ink.finish()
