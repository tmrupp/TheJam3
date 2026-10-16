class_name BeastSoul
extends Breach
## One of the eldritch beast's souls (BeastSouls), lying on a floor of a level the beast sent it
## into: a knot of pink flesh rooted in the floor with one of the beast's eyes in it, beating. It is a
## breach of its own (Breach): while the wizard is near, abominations climb out of it, and two more
## are laid round it each time its level is entered (MapInfo._spawn_souls). It takes HP blows; any
## hex bolt, dash or parry wounds it, even one that only stuns (Wound.least). Destroyed, it is gone
## for the rest of the run (MapInfo.soul_destroyed), and one of the beast's eyes shuts. It drops no
## stars. Placed by MapInfo, not with the level, so its level's record knows nothing of it. Nothing
## here draws from any RNG.

## The blows it takes, how often it beats (seconds), and its size (px: the knot's radius).
const SOUL_HP: int = 8
const BEAT: float = 0.8
const SIZE: float = 40.0
## Its blows left, as notches over it: how far apart and how big (px).
const NOTCH_GAP: float = 17.0
const NOTCH_R: float = 6.0

var wound: Wound
var ink: InkCanvas
var t: float = 0.0
## Its blows left when it was last drawn, and seconds since it was last struck (the flash).
var _last_hp: int = SOUL_HP
var _struck: float = 99.0


func _init() -> void:
	wound = Wound.new()
	wound.name = "Wound"
	wound.hp = SOUL_HP
	wound.least = 1
	wound.stars = false
	add_child(wound)
	add_to_group(&"hex_target")


func setup(info: MapInfo, v: Vector2i) -> void:
	map_info = info
	cell = v


func _ready() -> void:
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)
	wound.slain.connect(_on_destroyed)
	add_to_group(&"riso_art")


func _on_destroyed() -> void:
	if map_info != null:
		map_info.soul_destroyed()


## A knot of pink flesh on the floor, its roots spreading along it, beating; in it one of the
## beast's eyes (paper, its night pupil turned on the wizard). It swells pink as an abomination
## climbs out of it, flashes as it is struck, and its blows left are paper notches over it.
func _process(delta: float) -> void:
	t += delta
	if wound.hp < _last_hp:
		_struck = 0.0
	_last_hp = wound.hp
	_struck += delta
	if ink == null:
		return
	ink.begin()
	var floor_y: float = 64.0
	if map_info != null and map_info.tile_map != null:
		floor_y = float(map_info.tile_map.tile_set.tile_size.y) * map_info.tile_map.global_scale.y * 0.5
	var beat: float = pow(maxf(0.0, sin(t / BEAT * TAU)), 4.0)
	var surge: float = clampf(surging / Breach.SURGE, 0.0, 1.0) if surging >= 0.0 else 0.0
	var s: float = 1.0 + 0.1 * beat + 0.25 * surge
	var c: Vector2 = Vector2(0, floor_y - SIZE * 0.95 * s)
	# Its roots, along the floor either side.
	var roots: Array[PackedVector2Array] = []
	for k: int in range(6):
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var reach: float = SIZE * (1.4 + 0.35 * floorf(float(k) * 0.5))
		var pts: PackedVector2Array = PackedVector2Array()
		for j: int in range(6):
			var u: float = float(j) / 5.0
			pts.append(Vector2(side * (SIZE * 0.4 + reach * u), floor_y - 4.0 - 10.0 * (1.0 - u) * (1.0 - u) + 2.0 * sin(t * 2.0 + float(k) + u * 4.0)))
		roots.append_array(RisoDecor.strip(pts, 9.0, 2.0))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], roots)
	ink.ink(RisoPrint.PINK, 1.0, roots, false)
	ink.ink(RisoPrint.BLUE, 0.45, roots, false)
	if surge > 0.0:
		ink.ink(RisoPrint.PINK, 0.15 + 0.35 * surge, [RisoShapes.circle(c, SIZE * (1.6 + 0.5 * surge), 24)])
	var knot: PackedVector2Array = AbominationArt.gumdrop(c, SIZE * s)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], [knot])
	ink.ink(RisoPrint.PINK, 1.0, [knot], false)
	ink.ink(RisoPrint.BLUE, 0.25 + 0.15 * beat, [knot], false)
	if _struck < 0.25:
		ink.ink(RisoPrint.PINK, 0.6 * (1.0 - _struck / 0.25), [knot], false)
	# Its eye, the beast's, looking at the wizard.
	var look: Vector2 = Vector2.ZERO
	var player: Player = Stage.player()
	if player != null and is_instance_valid(player):
		look = (player.global_position - global_position).normalized()
	var e: Vector2 = c + Vector2(0, -SIZE * 0.1)
	var white: PackedVector2Array = RisoShapes.circle(e, SIZE * 0.42, 18)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [white])
	ink.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.circle(e + look * SIZE * 0.16, SIZE * 0.2, 12)], false)
	# Its blows left, as notches of paper over it.
	var notches: Array[PackedVector2Array] = []
	for i: int in range(wound.hp):
		notches.append(RisoShapes.circle(Vector2((float(i) - float(SOUL_HP - 1) * 0.5) * NOTCH_GAP, c.y - SIZE * 1.6), NOTCH_R, 10))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], notches)
	ink.ink(RisoPrint.PINK, 1.0, notches, false)
	ink.finish()
