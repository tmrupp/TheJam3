extends Node2D
class_name TrialPiece
## A piece of a class's trial (Timetable; laid by `lay` as the trial begins, MapInfo.begin_trial):
## what the subject must be used on, for what it does, in the lecture hall. Each kind passes only to
## its spell used literally; anything else glances off it. Done, it fades (TrialPieceArt), and once
## every piece of the trial is done the trial is passed (MapInfo.trial_piece_done). A hex's or a
## seeker's trial is a mock glyph seal instead (GlyphSeal). Its kinds, by subject:
## - slash: cords hanging from the ceiling to over the floor (CORDS_AT), each cut by a slash;
## - nova: SIGILS sigils in a ring about where the wizard stands, all caught in one nova at once
##   (struck in the same physics step; any fewer and none counts);
## - push: a heavy stone on a track along the floor, shoved a cell a gust (STONE_RUN cells) to the
##   mark at its end;
## - lunge: a hoop hung a row over the floor, lunged through while off the ground;
## - levitate: a mark high over the floor (LEVITATE_AT), touched while floating;
## - ferry: a mark over the floor (FERRY_AT), touched while riding a raft of the wizard's own;
## - astral: a mark sunk in the stone of the tiers, touched by the projection;
## - awareness: three hidden marks, seen and touched only while sensing;
## - rift: two marks, on the floor and on the top tier, each with an end of the wizard's rift opened
##   on it;
## - warp: a mark over the lectern, done by warping out of the hall and coming back into it
##   (MapInfo._watch_timetable).
## Nothing here draws from any RNG.

## The kinds of piece.
const CORD: StringName = &"cord"
const SIGIL: StringName = &"sigil"
const STONE: StringName = &"stone"
const HOOP: StringName = &"hoop"
const MARK: StringName = &"mark"
## How many sigils, how far their ring reaches (px, across and up and down), and how far the stone
## runs (cells).
const SIGILS: int = 6
const RING: Vector2 = Vector2(125.0, 45.0)
const STONE_RUN: int = 3
## Where the marks are, in a lecture hall (cells across from its lectern's wall, rows up from its
## floor; see _in): the levitate and ferry marks hang over the floor; the astral mark is sunk in the
## second tier's stone; the awareness marks lie on the floor, the second tier and the top tier; the
## rift's on the floor and the top tier; the warp's over the lectern.
const LEVITATE_AT: Vector2i = Vector2i(3, 3)
const FERRY_AT: Vector2i = Vector2i(2, 2)
const ASTRAL_AT: Vector2i = Vector2i(8, 0)
const AWARE_AT: Array[Vector2i] = [Vector2i(0, 0), Vector2i(9, 2), Vector2i(12, 4)]
const RIFT_AT: Array[Vector2i] = [Vector2i(0, 0), Vector2i(12, 4)]
const WARP_AT: Vector2i = Vector2i(2, 1)
## Where the cords hang (clear of the great bell's cord, a cell from the lectern's wall), the stone's
## mark, and the hoop and the sigils' ring's middle (on the floor where the wizard stands, a row up for
## the hoop).
const CORDS_AT: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(5, 0)]
const STONE_GOAL: Vector2i = Vector2i(2, 0)
const HOOP_AT: Vector2i = Vector2i(2, 1)
const RING_AT: Vector2i = Vector2i(2, 0)
## How near (px) the wizard (or a rift's end) must come to touch a mark.
const TOUCH: float = 60.0
## How far under the wizard's middle (px) the floor is felt for, to tell them off the ground.
const FEET: float = 44.0
## How long a done piece takes to fade (seconds).
const FADE: float = 0.5
## The prefab (loaded when first needed).
const SCENE: String = "res://prefabs/trial_piece.tscn"

var map_info: MapInfo
## Its kind, and the trial's subject.
var kind: StringName = MARK
var spell: StringName = &""
## A hidden mark (awareness): seen and touched only while the wizard senses.
var veiled: bool = false
## How far up (px) the ceiling is over it (a cord's and a hoop's hang from it).
var ceiling_up: float = 0.0
## A stone's track: where it starts and the mark it is shoved to (world x), and a cell (px).
var start_x: float = 0.0
var goal_x: float = 0.0
var step: float = 128.0
## Whether it is done, seconds since it was (-1 until it is), since a blow glanced off it, and the
## physics step a sigil was last struck in (-1 never).
var done: bool = false
var since_done: float = -1.0
var since_glance: float = 99.0
var struck_at: int = -1
## The sigils of its ring (a sigil's), itself among them.
var ring: Array[TrialPiece] = []
## Its own clock (the art).
var t: float = 0.0


## The pieces of the trial of `a` in lecture hall `hall` of `info`'s level, laid in the scene; [] for
## a spell with no pieces (a hex's or a seeker's: a mock glyph seal).
static func lay(info: MapInfo, hall: int, a: StringName) -> Array[TrialPiece]:
	var out: Array[TrialPiece] = []
	var cell: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i.ZERO).x
	match a:
		&"slash":
			for at: Vector2i in CORDS_AT:
				out.append(_piece(info, hall, a, CORD, at))
		&"nova":
			var c: Vector2 = info.cell_position(_in(info, hall, RING_AT)) + Vector2(0, -24)
			for k: int in range(SIGILS):
				var angle: float = TAU * float(k) / float(SIGILS)
				var s: TrialPiece = _piece(info, hall, a, SIGIL, RING_AT)
				s.global_position = c + Vector2(cos(angle) * RING.x, sin(angle) * RING.y)
				out.append(s)
			for s: TrialPiece in out:
				s.ring = out
		&"push":
			var stone: TrialPiece = _piece(info, hall, a, STONE, STONE_GOAL + Vector2i(STONE_RUN, 0))
			stone.start_x = stone.global_position.x
			stone.goal_x = info.cell_position(_in(info, hall, STONE_GOAL)).x
			stone.step = cell
			out.append(stone)
		&"lunge":
			out.append(_piece(info, hall, a, HOOP, HOOP_AT))
		&"levitate":
			out.append(_piece(info, hall, a, MARK, LEVITATE_AT))
		&"ferry":
			out.append(_piece(info, hall, a, MARK, FERRY_AT))
		&"astral":
			out.append(_piece(info, hall, a, MARK, ASTRAL_AT))
		&"awareness":
			for at: Vector2i in AWARE_AT:
				var m: TrialPiece = _piece(info, hall, a, MARK, at)
				m.veiled = true
				out.append(m)
		&"rift":
			for at: Vector2i in RIFT_AT:
				out.append(_piece(info, hall, a, MARK, at))
		&"warp":
			out.append(_piece(info, hall, a, MARK, WARP_AT))
	return out


## Cell `at` of lecture hall `hall` (across from its lectern's wall, toward its tiers, and rows up
## from its floor).
static func _in(info: MapInfo, hall: int, at: Vector2i) -> Vector2i:
	var inside: Rect2i = info.world.halls[hall]["inside"]
	var rise: int = info.world.halls[hall]["rise"]
	var wall: int = inside.position.x if rise > 0 else inside.end.x - 1
	return Vector2i(wall + rise * at.x, inside.end.y - 1 - at.y)


## A piece of `kind` for the trial of `a` at cell `at` of lecture hall `hall` (see _in), in the scene.
static func _piece(info: MapInfo, hall: int, a: StringName, of: StringName, at: Vector2i) -> TrialPiece:
	var p: TrialPiece = (load(SCENE) as PackedScene).instantiate() as TrialPiece
	p.map_info = info
	p.kind = of
	p.spell = a
	var v: Vector2i = _in(info, hall, at)
	var inside: Rect2i = info.world.halls[hall]["inside"]
	var cell: float = info.cell_position(Vector2i(0, 1)).y - info.cell_position(Vector2i.ZERO).y
	p.ceiling_up = (float(v.y - inside.position.y) + 0.5) * cell
	info.map_elements.add_child(p)
	p.global_position = info.cell_position(v)
	return p


func _ready() -> void:
	add_to_group(&"trial_piece")
	if kind in [CORD, SIGIL, STONE, HOOP]:
		add_to_group(&"hex_target")


## Struck by spell `a` (&"" for a plain blow), cast from `from`, heading `dir` (SpellStrike.strike,
## HexBolt): it answers if that is its spell used for what it does (see the class description), else
## the blow glances off.
func struck(a: StringName, _from: Vector2, dir: Vector2) -> void:
	if done:
		return
	if a != spell or not kind in [CORD, SIGIL, STONE, HOOP]:
		_glance()
		return
	match kind:
		CORD:
			_finish()
		SIGIL:
			struck_at = Engine.get_physics_frames()
			if ring.all(func(s: TrialPiece) -> bool: return is_instance_valid(s) and s.struck_at == struck_at):
				for s: TrialPiece in ring:
					s._finish()
		STONE:
			# Shoved a cell the way the gust blows, along its track and no further.
			var lo: float = minf(start_x, goal_x)
			var hi: float = maxf(start_x, goal_x)
			global_position.x = clampf(global_position.x + signf(dir.x) * step, lo, hi)
			RisoFx.burst(&"rubble", global_position + Vector2(0, 50), Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
			if absf(global_position.x - goal_x) < 1.0:
				_finish()
		HOOP:
			if _airborne():
				_finish()
			else:
				_glance()


## A blow that is not its spell, used literally: it jolts.
func _glance() -> void:
	since_glance = 0.0
	Wound.shake(2.0, 0.08)


## Whether the wizard is off the ground: no floor just under their middle.
func _airborne() -> bool:
	var player: Player = Stage.player()
	return player != null and map_info != null and not map_info.solid_at(player.global_position + Vector2(0, FEET))


## Done: it fades, and tells the trial.
func _finish() -> void:
	if done:
		return
	done = true
	since_done = 0.0
	remove_from_group(&"hex_target")
	RisoFx.burst(&"gain", global_position + Vector2(0, -20), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	if map_info != null:
		map_info.trial_piece_done(self)


## Whether the wizard senses now (awareness): a hidden mark shows.
func shown() -> bool:
	if not veiled:
		return true
	var player: Player = Stage.player()
	var aware: Awareness = player.get_node_or_null("Awareness") as Awareness if player != null else null
	return aware != null and aware.active()


## Whether a mark's spell is being used on it now (see the class description).
func _touched() -> bool:
	var player: Player = Stage.player()
	if player == null or map_info == null:
		return false
	if spell == &"rift":
		return Rift.current_ends(map_info).any(func(p: Portal) -> bool: return p.global_position.distance_to(global_position) <= TOUCH)
	if player.global_position.distance_to(global_position) > TOUCH:
		return false
	match spell:
		&"levitate":
			var lev: Levitate = player.get_node_or_null("Levitate") as Levitate
			return lev != null and lev.floating()
		&"ferry":
			for n: Node in map_info.map_elements.get_children():
				var raft: FerryRaft = n as FerryRaft
				if raft != null and absf(raft.global_position.x - player.global_position.x) <= FerryRaft.HALF_WIDTH and raft.global_position.y - player.global_position.y > 0.0 and raft.global_position.y - player.global_position.y < 110.0:
					return true
			return false
		&"astral":
			return player.phasing
		&"awareness":
			return shown()
	return false


## A warp's mark: the wizard came back into the hall after warping out of it.
func came_back() -> void:
	if spell == &"warp":
		_finish()


func _physics_process(delta: float) -> void:
	t += delta
	since_glance += delta
	if done:
		since_done += delta
		if since_done >= FADE:
			queue_free()
		return
	if kind == MARK and spell != &"warp" and _touched():
		_finish()
