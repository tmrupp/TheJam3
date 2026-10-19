extends RigidBody2D
class_name Scholar
## The institute's people (docs/REGIONS_PLAN.md §7; Institute places them), printed after the
## original wizard (ScholarArt): robed, faceless under a floppy hat, eyes lit, a spell's orb at the
## shoulder. Each walks its own floor, hopping a step of a cell and stopping at a ledge, never more
## than HOME cells from where it was laid (a class keeps together), and fights whatever is nearest
## of the wizard and the abominations (Abomination) that it can see within its sight, keeping its
## distance from it as its spells want; with nothing to fight it goes back to its place. Every
## RETARGET seconds it looks again. Its touch hurts, a parry's stun stops it, and its
## Wound is given as it is placed (LevelLoader.arm); `setup` sets its health by kind.
##
## The kinds (`kind`, set in each prefab):
## - a student: casts a weak bolt (a Bullet printed as one, wounding the abominations it meets as
##   well) every STUDENT_EVERY seconds while it sees its foe, after a short wind-up; one cast in
##   MISFIRE fizzles in its hand or flies wide (hashed from its cell and the casts it has made, no
##   RNG). It belongs to the nearest master within CLASS_REACH: when that master falls, it scatters,
##   running from the wizard for SCATTER seconds without casting.
## - a master: has mastered one of the wizard's damage spells (`ability`, Institute.MASTERIES),
##   shown by its glyph on its orb, and casts it: a hex bolt, a seeker turning after the wizard, a
##   slash in front of it, a nova all round it, a push in a cone that throws the wizard back, or a
##   lunge along its floor. Its melee spells wait until the foe is within their reach. Beaten, it
##   leaves a lesson where it fell (Lesson) teaching a tier of its spell, once a master.
## - an instructor: a classroom's master (`hall`, its classroom in LevelGen.halls), teaching the
##   room's subject now (MapInfo.subject_of), its orb bearing it. It casts the subject if a damage
##   spell, else its department's (Timetable.default_spell), and it is the institute at its
##   strongest: INSTRUCTOR_HP more blows, casting INSTRUCTOR_HASTE times as fast, and turning on the
##   wizard turns its whole class with it. Turned on the wizard, it moves as its subject does
##   (`move`): a warp every MOVE_EVERY seconds to another floor of its room, a rift back and forth
##   between its room's two furthest floors, ferrying across its room on a raft without a stop
##   (FERRY_SPEED), projecting itself for ASTRAL_TIME every MOVE_EVERY (unhurt meanwhile,
##   Wound.unhurt); levitating, it always hovers HOVER px over the floor, and, aware, it sees the
##   wizard through rock. Beaten by the wizard's own blow it leaves a paper of its subject at the
##   spell's top tier, once a room (MapInfo.instructor_fell).
## - a proctor: casts nothing, but every SHIELD_EVERY seconds gives each student and master within
##   SHIELD_REACH that has none a shield of one plate (Shield).
## - a librarian: casts nothing, but hushes the air round it (HUSH px): while the wizard is in it
##   they are drowsy, as in sleep fog (Player.make_drowsy), and their spells do nothing.
## A melee spell or a touch on the wizard comes from its HitBox's Damager, so a parry catches it
## as it catches any touch.
##
## A master's fall leaves something only to the wizard's own blow (`wizard_blow`): a lesson out in
## the level, an instructor's paper in a classroom (its class then cannot be attended until the next
## bell seats it again); one felled by abominations leaves nothing. A proctor out in the corridors walks them, PATROL cells either way of
## its place, while a class is on (MapInfo.class_on: a period, not passing time).
##
## The timetable (Timetable): it leaves the wizard be (calm) while they are where they belong, and
## turns on them (`roused`) once it sees them where they do not (MapInfo.wizard_belongs), with real
## line of sight, so slipping past one facing away works; those within ROUSE_REACH of it turn with
## it, a local fuss. Struck by the wizard, or seeing them cast a spell (MapInfo.wizard_cast), it turns
## on them wherever they are. The next bell calms it (MapInfo.ring_period). In a level with no
## timetable it is always roused. The abominations it fights whatever the time. Nothing here draws
## from any RNG.

## Seconds between looks for a foe, and how far (px) each kind sees one.
const RETARGET: float = 0.25
const SIGHT: Dictionary = {&"student": 900.0, &"master": 1100.0, &"proctor": 900.0, &"librarian": 700.0}
## Walking speed (px/s) by kind (a little faster on a harder preset, Difficulty.speed); the hop up a
## step (px/s up) and the fastest fall.
const SPEED: Dictionary = {&"student": 70.0, &"master": 80.0, &"proctor": 60.0, &"librarian": 40.0}
const HOP: float = -580.0
const MAX_FALL: float = 900.0
## How far it may stray from where it was laid (cells), and how near its place counts as there (px).
const HOME: int = 5
const HOME_SLACK: float = 24.0
## The distance (px) each kind keeps from its foe (a master's by its spell, KEEP_MASTER), and the
## slack either side of it before it walks.
const KEEP: Dictionary = {&"student": 420.0, &"proctor": 320.0, &"librarian": 200.0}
const KEEP_MASTER: Dictionary = {&"hex": 480.0, &"seeker": 560.0, &"slash": 110.0, &"nova": 150.0, &"push": 240.0, &"lunge": 380.0}
const KEEP_SLACK: float = 60.0
## How far ahead (px) it looks for a wall to hop or a ledge to stop at.
const AHEAD: float = 22.0
## Health by kind (the Wound LevelLoader.arm gave, set again as it is placed), and a master's more
## for each row past its band's first (MASTER_HP_STEP).
const HP: Dictionary = {&"student": 2, &"master": 6, &"proctor": 3, &"librarian": 3}
const MASTER_HP_STEP: int = 1

## A student's bolt: how often (seconds), its wind-up, its speed (px/s), and the share of casts that
## misfire (half of those fizzle, half fly WIDE radians off).
const STUDENT_EVERY: float = 3.2
const STUDENT_WIND: float = 0.5
const STUDENT_SHOT: float = 300.0
const MISFIRE: float = 0.3
const WIDE: float = 0.55
## The nearest master within CLASS_REACH px is a student's own; when it falls the student scatters
## for SCATTER seconds, at SCATTER_SPEED times its pace.
const CLASS_REACH: float = 1300.0
const SCATTER: float = 6.0
const SCATTER_SPEED: float = 1.8
## A master's spells: how often (seconds), the wind-up, and each spell's measures: the hex bolt's
## and the seeker's speed (px/s), the seeker's turn (radians a second) and life (seconds); the
## reach (px) of a slash (in front), a nova (all round), a push (a cone of PUSH_CONE radians either
## side) and how hard a push throws (px/s); a lunge's reach, speed (px/s) and how long it lasts.
const MASTER_EVERY: float = 2.6
const MASTER_WIND: float = 0.7
const HEX_SHOT: float = 520.0
const SEEKER_SHOT: float = 280.0
const SEEKER_TURN: float = 1.7
const SEEKER_LIFE: float = 4.0
const SLASH_REACH: float = 190.0
const NOVA_REACH: float = 240.0
const PUSH_REACH: float = 360.0
const PUSH_CONE: float = 0.6
const PUSH_THROW: float = 900.0
const LUNGE_REACH: float = 520.0
const LUNGE_SPEED: float = 1300.0
const LUNGE_TIME: float = 0.3
## The knock a melee spell gives the wizard (px/s).
const KNOCK: float = 400.0
## A proctor's shields: how often (seconds), how far (px), and how many plates each.
const SHIELD_EVERY: float = 5.0
const SHIELD_REACH: float = 560.0
const SHIELD_PLATES: int = 1
## A librarian's hush: how far round it (px).
const HUSH: float = 330.0
## Where it looks from and casts from (px over its feet), and where an abomination it fights is
## aimed at (px over its middle). The wizard is aimed at the middle of their body (see `aim_at`):
## aimed this high over it, a bolt flew clean over their head.
const EYE: float = 60.0
const AIM: float = 40.0
## Salt for the hash that deals a student's misfires.
const MISFIRE_DEAL: int = 6460
## How far (px) a scholar turning on the wizard takes those round it with it.
const ROUSE_REACH: float = 640.0
## How far a proctor out in the corridors walks either way of its place in a period (cells).
const PATROL: int = 10

## An instructor (see the class description): how many more blows it takes than a master out in the
## level, and how much faster it casts and moves; how often (seconds) it warps, rifts or projects
## itself, and how long a projection lasts; how high it hovers levitating (px), and how fast it ferries
## (px/s).
const INSTRUCTOR_HP: int = 14
const INSTRUCTOR_HASTE: float = 1.5
const MOVE_EVERY: float = 3.0
const ASTRAL_TIME: float = 1.4
const HOVER: float = 150.0
const HOVER_RISE: float = 240.0
const FERRY_SPEED: float = 170.0

## The bolt it casts (loaded when first cast: preloaded, it would load in a circle with the
## wizard's scripts, which name this one).
const SHOT: String = "res://prefabs/bullet.tscn"

## Which kind it is (see the class description): set in its prefab.
@export var kind: StringName = &"student"

var map_info: MapInfo
## The cell it was laid in; a master's spell and its hall (-1 for none).
var cell: Vector2i = Vector2i(-1, -1)
var ability: StringName = &""
var hall: int = -1
## The level's relic a master out in the level carries (Institute.populate), left where it falls to
## the wizard (MapInfo.relic_left); &"" for none, and once the relic is left or taken.
var relic: StringName = &""
## The move an instructor makes (&"" for none): see the class description. The seconds to its next
## warp, rift or projection, the seconds left of a projection, where it hovers (y, px), and which end
## of its room a rift took it to last.
var move: StringName = &""
var move_in: float = MOVE_EVERY
var projected: float = 0.0
var hover_y: float = INF
var rift_end: int = 0
## Where it was laid (x, px), +1 facing right or -1 left, how fast it falls, and whether it stands on
## something.
var home_x: float = INF
var facing: float = 1.0
var fall_speed: float = 0.0
var grounded: bool = false
## Walking now (the art swings its hem), and how far it has walked all told (px).
var walking: bool = false
var walked: float = 0.0
## Its foe (the wizard, an abomination, or null), and the seconds to its next look.
var foe: Node2D = null
var look_in: float = 0.0
## Seconds to its next cast (or shield), the wind-up under way (seconds into it, -1 while none), and
## seconds since it last cast (the art flares), whether that cast misfired, and how many it has made.
var cast_in: float = 1.0
var winding: float = -1.0
var since_cast: float = 9.0
var misfired: bool = false
var casts: int = 0
## A lunge under way: seconds left of it, and its way (+1 right, -1 left).
var lunging: float = 0.0
var lunge_way: float = 1.0
## A student's master (null for none: see own_master), whether it has been looked for, and the
## seconds left of its scattering.
var master: Scholar = null
var _found_master: bool = false
var scatter: float = 0.0
## Seconds since its proctor last shielded those round it (the art draws the links).
var since_shield: float = 9.0
## Its own clock (the art).
var t: float = 0.0
## Whether it has turned on the wizard (see the class description) until the next bell.
var roused: bool = false
## Whether the last blow it took was the wizard's (set as the wizard's spells strike it, cleared as an
## abomination bites it): its fall leaves a lesson only then.
var wizard_blow: bool = false
## A patrolling proctor's way (+1 right, -1 left), and where it was a step ago (to turn where it is
## stopped).
var patrol_way: float = 1.0
var _last_x: float = INF

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	map_info = info
	cell = v
	if extra is Dictionary:
		ability = StringName((extra as Dictionary).get("ability", &""))
		hall = int((extra as Dictionary).get("hall", -1))
		relic = StringName((extra as Dictionary).get("relic", &""))
		if relic != &"" and info != null and not info.relic_carried():
			relic = &""
	var kind_of_hall: StringName = info.world.halls[hall]["kind"] if info != null and info.world != null and hall >= 0 and hall < info.world.halls.size() else &""
	# A class's master teaches its hall's subject now.
	if kind_of_hall == &"lecture":
		ability = info.subject_of(hall)
		if kind == &"master" and not ability in Institute.MASTERIES:
			move = ability
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hp = int(HP.get(kind, 2))
		if kind == &"master" and info != null and info.here != null:
			wound.hp += MASTER_HP_STEP * maxi(0, info.here.depth - NextWorldDef.first_depth(&"institute"))
		if instructor():
			wound.hp += INSTRUCTOR_HP


## The spell it casts: the one it teaches, if a damage spell, else its department's
## (Timetable.default_spell).
func spell_cast() -> StringName:
	return ability if ability in Institute.MASTERIES else Timetable.default_spell(ability)


## Whether it is an instructor, a classroom's master (see the class description).
func instructor() -> bool:
	return kind == &"master" and map_info != null and map_info.world != null and hall >= 0 and hall < map_info.world.halls.size() and map_info.world.halls[hall]["kind"] == &"lecture"


## How much sooner it casts (and moves): an instructor INSTRUCTOR_HASTE, anyone else 1.
func haste() -> float:
	return INSTRUCTOR_HASTE if instructor() else 1.0


## Whether it walks the corridors now: a proctor out of the halls, while a class is on.
func patrolling() -> bool:
	return kind == &"proctor" and map_info != null and map_info.class_on() and Institute.hall_at(map_info.world, cell) < 0


func _ready() -> void:
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	move_and_collide(Vector2(0, 64))
	add_to_group(&"scholar")
	add_to_group(kind)
	facing = -1.0 if RisoDecor.h(int(cell.x * 31 + cell.y), cell, 0) < 0.5 else 1.0
	cast_in = 0.6 + RisoDecor.h(int(cell.x * 17 + cell.y * 5), cell, 1) * 1.4
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.slain.connect(_fallen)


## Whether it is stunned now.
func stunned() -> bool:
	var stunner: Stunner = Stunner.of(self)
	return stunner != null and stunner.stunned()


## Its HitBox's Damager: what its touch and its melee spells hurt the wizard through.
func damager() -> Damager:
	return get_node_or_null("HitBox/Damager") as Damager


## Where it casts from.
func eye() -> Vector2:
	return global_position + Vector2(0, -EYE)


func _physics_process(delta: float) -> void:
	t += delta
	since_cast += delta
	since_shield += delta
	if home_x == INF:
		home_x = global_position.x
		hover_y = global_position.y - HOVER
	own_master()
	_fall(delta)
	_examine(delta)
	walking = false
	var touch: Damager = damager()
	if touch != null:
		touch.set_physics_process(hostile())
	if stunned():
		winding = -1.0
		lunging = 0.0
		return
	if lunging > 0.0:
		_lunge_step(delta)
		return
	look_in -= delta
	if look_in <= 0.0:
		look_in = RETARGET
		foe = _find_foe()
	if foe != null and not is_instance_valid(foe):
		foe = null
	if kind == &"librarian":
		_hush()
	if scatter > 0.0:
		scatter = maxf(0.0, scatter - delta)
		_flee(delta)
		return
	_move(delta)
	if kind == &"proctor":
		_shield_others(delta)
		return
	if kind == &"librarian":
		return
	_cast(delta)


# ------------------------------------------------------------------ foes

## The nearest of the wizard and the abominations within its sight, with no rock between; null for
## none.
func _find_foe() -> Node2D:
	var sight: float = float(SIGHT.get(kind, 900.0))
	var best: Node2D = null
	var best_d: float = sight
	var player: Player = Stage.player()
	var candidates: Array[Node2D] = []
	if player != null and is_instance_valid(player) and not player.phasing and _turns_on(player):
		candidates.append(player)
	for node: Node in get_tree().get_nodes_in_group(&"abomination"):
		var a: Node2D = node as Node2D
		if a != null and not a.is_queued_for_deletion():
			candidates.append(a)
	for c: Node2D in candidates:
		var d: float = eye().distance_to(c.global_position)
		if d < best_d and _seen(eye(), c.global_position + aim_at(c)):
			best = c
			best_d = d
	return best


## Whether it is turned on the wizard now: always where there is no timetable, else once roused.
## Calm, its touch and its spells leave them be.
func hostile() -> bool:
	return roused or map_info == null or not map_info.timetabled()


## Whether it fights the wizard (`player`): always where there is no timetable; else once roused,
## and it is roused here by seeing them where they do not belong.
func _turns_on(player: Player) -> bool:
	if map_info == null or not map_info.timetabled():
		return true
	if not roused and not map_info.wizard_belongs() and sees(player):
		rouse()
	return roused


## Whether it sees `target`: within its sight, with nothing solid between.
func sees(target: Node2D) -> bool:
	return eye().distance_to(target.global_position) <= float(SIGHT.get(kind, 900.0)) and _seen(eye(), target.global_position + aim_at(target))


## It turns on the wizard, and every scholar within ROUSE_REACH with it, and in a hall everyone in
## that hall (a class fights together), until the next bell.
func rouse() -> void:
	var room: int = Institute.hall_at(map_info.world, map_info.cell_at(global_position)) if map_info != null and map_info.world != null else -1
	for node: Node in get_tree().get_nodes_in_group(&"scholar"):
		var s: Scholar = node as Scholar
		if s == null or s.is_queued_for_deletion():
			continue
		var together: bool = room >= 0 and Institute.hall_at(map_info.world, map_info.cell_at(s.global_position)) == room
		if s == self or together or s.global_position.distance_to(global_position) <= ROUSE_REACH:
			s.roused = true


## A bell rang: it calms down, and leaves the wizard be until it sees them out of place again.
func calm() -> void:
	roused = false
	if foe is Player:
		foe = null
		winding = -1.0


## Where on `target` (px from where it stands) a scholar aims its bolts, and a seeker steers: the
## middle of the wizard's body (their own middle), or AIM over an abomination's.
static func aim_at(target: Node2D) -> Vector2:
	return Vector2.ZERO if target is Player else Vector2(0, -AIM)


## Whether it sees from `from` to `to`: through anything, aware (an instructor of awareness), else
## with nothing solid between.
func _seen(from: Vector2, to: Vector2) -> bool:
	return move == &"awareness" or _clear(from, to)


## Whether nothing solid (rock, a shut door or gate) stands between `from` and `to`.
func _clear(from: Vector2, to: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 4, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## A student's master: the nearest master within CLASS_REACH, looked for the first time it is
## asked (a student asleep in a far chunk has not looked yet); null for none, or for another kind.
func own_master() -> Scholar:
	if not _found_master:
		_found_master = true
		if kind == &"student":
			master = _nearest_master()
	return master


## The nearest master within CLASS_REACH, or null.
func _nearest_master() -> Scholar:
	var best: Scholar = null
	var best_d: float = CLASS_REACH
	for node: Node in get_tree().get_nodes_in_group(&"master"):
		var m: Scholar = node as Scholar
		if m == null or m == self or m.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_to(m.global_position)
		if d < best_d:
			best = m
			best_d = d
	return best


# ------------------------------------------------------------------ walking

## Fall until something is underfoot; resting on the floor, stay put (no bounce). Levitating, it
## rises or sinks to its hover instead.
func _fall(delta: float) -> void:
	if move == &"levitate" and hover_y != INF:
		var dy: float = clampf(hover_y - global_position.y, -HOVER_RISE * delta, HOVER_RISE * delta)
		move_and_collide(Vector2(0, dy))
		fall_speed = 0.0
		grounded = false
		return
	fall_speed = minf(fall_speed + gravity * delta, MAX_FALL)
	var hit: KinematicCollision2D = move_and_collide(Vector2(0, fall_speed * delta))
	grounded = hit != null and hit.get_normal().y < -0.7
	if hit != null:
		fall_speed = 0.0


## Toward or away from its foe to keep its distance, else back to its place; never past HOME cells
## from it.
func _move(delta: float) -> void:
	var want: float = 0.0
	if move == &"ferry" and hostile():
		_ferry(delta)
		return
	if foe != null:
		var to: Vector2 = foe.global_position - global_position
		if absf(to.x) > 8.0 and winding < 0.0:
			facing = signf(to.x)
		var keep: float = float(KEEP_MASTER.get(spell_cast(), 300.0)) if kind == &"master" else float(KEEP.get(kind, 300.0))
		var d: float = absf(to.x)
		if d > keep + KEEP_SLACK:
			want = signf(to.x)
		elif d < keep - KEEP_SLACK:
			want = -signf(to.x)
	elif patrolling():
		# Its round: to PATROL cells either way of its place, turning there, at a ledge or where it is
		# stopped.
		var edge: float = home_x + patrol_way * float(PATROL) * _cell_px()
		var stuck: bool = _last_x != INF and absf(global_position.x - _last_x) < 0.01 and grounded
		if (edge - global_position.x) * patrol_way <= HOME_SLACK or (grounded and not _floor_ahead(patrol_way)) or stuck:
			patrol_way = -patrol_way
		want = patrol_way
		facing = want
	else:
		var back: float = home_x - global_position.x
		if absf(back) > HOME_SLACK:
			want = signf(back)
			facing = want
	_last_x = global_position.x
	if winding >= 0.0 or want == 0.0:
		return
	var reach: float = float(PATROL if patrolling() else HOME) * _cell_px()
	if absf(global_position.x + want * 8.0 - home_x) > reach and signf(global_position.x - home_x) == want:
		return
	_step(want, float(SPEED.get(kind, 60.0)) * Difficulty.speed() * delta)


## A step of `dist` px the way `way` points along its floor: hopping a wall a cell high, stopping
## at a ledge.
func _step(way: float, dist: float) -> void:
	if grounded and _wall_ahead(way):
		fall_speed = HOP
		grounded = false
	elif grounded and not _floor_ahead(way):
		return
	var hit: KinematicCollision2D = move_and_collide(Vector2(way * dist, 0))
	if hit == null or absf(hit.get_normal().x) < 0.7:
		walking = true
		walked += dist


## Scattering: away from the wizard, faster, anywhere along its floor.
func _flee(delta: float) -> void:
	var player: Player = Stage.player()
	var way: float = facing
	if player != null and is_instance_valid(player):
		way = -signf(player.global_position.x - global_position.x)
		if way == 0.0:
			way = facing
	facing = way
	_step(way, float(SPEED.get(kind, 60.0)) * SCATTER_SPEED * Difficulty.speed() * delta)


func _wall_ahead(way: float) -> bool:
	return test_move(global_transform.translated(Vector2(0, -4)), Vector2(AHEAD * way, 0))


func _floor_ahead(way: float) -> bool:
	return test_move(global_transform.translated(Vector2(AHEAD * way, 0)), Vector2(0, 12))


## A level cell's width (px).
func _cell_px() -> float:
	if map_info == null or map_info.tile_map == null:
		return 128.0
	return float(map_info.tile_map.tile_set.tile_size.x) * map_info.tile_map.global_scale.x


# ------------------------------------------------------------------ an instructor's move

## An instructor's move (see the class description), while it is turned on the wizard: a warp, a rift
## or a projection every MOVE_EVERY seconds (sooner by its haste), whether or not it sees them just
## now; a projection running out.
func _examine(delta: float) -> void:
	if move == &"" or stunned():
		return
	if projected > 0.0:
		projected = maxf(0.0, projected - delta)
		if projected == 0.0:
			_unhurt(false)
	if not (move in [&"warp", &"rift", &"astral"]) or not hostile():
		return
	move_in -= delta * haste()
	if move_in > 0.0 or winding >= 0.0 or lunging > 0.0:
		return
	move_in = MOVE_EVERY
	match move:
		&"astral":
			projected = ASTRAL_TIME
			_unhurt(true)
			RisoFx.burst(&"gain", eye(), Vector2.ZERO, [RisoPrint.BLUE, RisoPrint.NIGHT])
		&"warp":
			var spots: Array[Vector2i] = floors()
			if spots.size() > 1:
				var k: int = int(RisoDecor.h(int(cell.x * 13 + cell.y), cell, casts + int(walked)) * float(spots.size())) % spots.size()
				if map_info.cell_at(global_position) == spots[k]:
					k = (k + 1) % spots.size()
				_jump_to(spots[k])
		&"rift":
			var spots: Array[Vector2i] = floors()
			if spots.size() > 1:
				rift_end = 1 - rift_end
				_jump_to(spots[0] if rift_end == 0 else spots[spots.size() - 1])


## Whether blows leave it unhurt (a projection, Wound.unhurt).
func _unhurt(on: bool) -> void:
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.unhurt = on


## The floors of its hall it may warp or rift to (clear cells with rock under them and clear either
## side, so it is not wedged against a wall, a door or a glyph seal, in its hall's inside), from the
## left; none for a scholar with no hall.
func floors() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map_info == null or map_info.world == null or hall < 0 or hall >= map_info.world.halls.size():
		return out
	var w: LevelGen = map_info.world
	var inside: Rect2i = w.halls[hall]["inside"]
	for x: int in range(inside.position.x, inside.end.x):
		for y: int in range(inside.position.y, inside.end.y):
			var v: Vector2i = Vector2i(x, y)
			if w.is_ground(v + Vector2i.DOWN) and _room(w, v) and _room(w, v + Vector2i.LEFT) and _room(w, v + Vector2i.RIGHT):
				out.append(v)
	return out


## Whether cell `v` of `w` has room for it: no rock, door or glyph seal in it.
static func _room(w: LevelGen, v: Vector2i) -> bool:
	return not w.is_ground(v) and not (w.get_cell(v).type in [LevelGen.Type.EXAM_DOOR, LevelGen.Type.GLYPH_SEAL, LevelGen.Type.DOOR])


## Gone from where it stands and there at once, on the floor of cell `v`: where it keeps to now.
func _jump_to(v: Vector2i) -> void:
	RisoFx.burst(&"hit", eye(), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
	global_position = map_info.cell_position(v)
	move_and_collide(Vector2(0, 64))
	home_x = global_position.x
	fall_speed = 0.0
	RisoFx.burst(&"gain", eye(), Vector2.ZERO, [RisoPrint.PINK, RisoPrint.NIGHT])


## Ferrying: across its hall on its raft and back, without a stop, turning at the hall's walls, a
## wall or a ledge; facing its foe to cast.
func _ferry(delta: float) -> void:
	var stuck: bool = _last_x != INF and absf(global_position.x - _last_x) < 0.01 and grounded
	_last_x = global_position.x
	if map_info != null and map_info.world != null and hall >= 0 and hall < map_info.world.halls.size():
		var inside: Rect2i = map_info.world.halls[hall]["inside"]
		var left: float = map_info.cell_position(inside.position).x
		var right: float = map_info.cell_position(Vector2i(inside.end.x - 1, inside.position.y)).x
		if (patrol_way < 0.0 and global_position.x <= left) or (patrol_way > 0.0 and global_position.x >= right):
			patrol_way = -patrol_way
	if stuck or (grounded and not _floor_ahead(patrol_way)):
		patrol_way = -patrol_way
	facing = signf(foe.global_position.x - global_position.x) if foe != null and absf(foe.global_position.x - global_position.x) > 8.0 else patrol_way
	_step(patrol_way, FERRY_SPEED * Difficulty.speed() * delta)


# ------------------------------------------------------------------ casting

## Wind up and cast at its foe: a student its bolt, a master its spell (see the class description).
func _cast(delta: float) -> void:
	if winding >= 0.0:
		winding += delta
		if foe == null:
			winding = -1.0
			return
		if winding >= _wind():
			winding = -1.0
			_release()
		return
	if foe == null:
		return
	cast_in -= delta * Difficulty.attack() * haste()
	if cast_in > 0.0 or not _in_reach():
		return
	cast_in = MASTER_EVERY if kind == &"master" else STUDENT_EVERY
	winding = 0.0


## How long its wind-up takes.
func _wind() -> float:
	return MASTER_WIND if kind == &"master" else STUDENT_WIND


## How far through its wind-up it is (0 to 1), or -1 while not winding up (the art).
func wind_up() -> float:
	return clampf(winding / _wind(), 0.0, 1.0) if winding >= 0.0 else -1.0


## Whether its foe is where its spell reaches: always for a bolt; within the reach of a melee spell.
func _in_reach() -> bool:
	if kind != &"master":
		return true
	var d: float = global_position.distance_to(foe.global_position)
	match spell_cast():
		&"slash":
			return d <= SLASH_REACH
		&"nova":
			return d <= NOVA_REACH
		&"push":
			return d <= PUSH_REACH
		&"lunge":
			return d <= LUNGE_REACH and absf(foe.global_position.y - global_position.y) < 64.0
	return true


## The wind-up is over: the spell goes off.
func _release() -> void:
	casts += 1
	since_cast = 0.0
	misfired = false
	if kind == &"student":
		var roll: float = RisoDecor.h(MISFIRE_DEAL + casts, cell, casts)
		if roll < MISFIRE * 0.5:
			# A fizzle: a puff in its hand, and nothing.
			misfired = true
			RisoFx.burst(&"hit", eye() + Vector2(facing * 30.0, 0), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
			return
		var off: float = 0.0
		if roll < MISFIRE:
			misfired = true
			off = WIDE if RisoDecor.h(MISFIRE_DEAL, cell, casts + 7) < 0.5 else -WIDE
		_shoot(STUDENT_SHOT, off, &"student")
		return
	match spell_cast():
		&"hex":
			_shoot(HEX_SHOT, 0.0, &"hex")
		&"seeker":
			var shot: Bullet = _shoot(SEEKER_SHOT, 0.0, &"seeker")
			if shot != null:
				shot.homing = foe
				shot.homing_aim = aim_at(foe)
				shot.turn = SEEKER_TURN
				shot.life = SEEKER_LIFE
		&"slash":
			_strike_round(SLASH_REACH, true, 0.0)
			SpellMark.leave(&"slash", global_position + Vector2(0, -AIM), Vector2(facing, 0), SLASH_REACH, PUSH_CONE + 0.5, RisoPrint.PINK, self)
		&"nova":
			_strike_round(NOVA_REACH, false, 0.0)
			SpellMark.leave(&"nova", global_position + Vector2(0, -AIM), Vector2.RIGHT, NOVA_REACH, PI, RisoPrint.PINK, self)
		&"push":
			_strike_round(PUSH_REACH, true, PUSH_THROW)
			SpellMark.leave(&"push", global_position + Vector2(0, -AIM), Vector2(facing, 0), PUSH_REACH, PUSH_CONE, RisoPrint.PINK, self)
		&"lunge":
			lunging = LUNGE_TIME
			lunge_way = facing
			SpellMark.leave(&"lunge", global_position + Vector2(0, -AIM), Vector2(facing, 0), LUNGE_SPEED * LUNGE_TIME, 0.0, RisoPrint.PINK)


## A bolt at its foe, `off` radians off true, printed as `spell`; it wounds the abominations it
## meets on the way. Returns it (null if it has no foe).
func _shoot(speed: float, off: float, spell: StringName) -> Bullet:
	if foe == null or map_info == null or not is_instance_valid(map_info.map_elements):
		return null
	var from: Vector2 = eye() + Vector2(facing * 26.0, 0)
	var aim: Vector2 = (foe.global_position + aim_at(foe) - from).normalized().rotated(off)
	var shot: Bullet = (load(SHOT) as PackedScene).instantiate() as Bullet
	map_info.map_elements.add_child(shot)
	shot.global_position = from
	shot.setup(aim * speed, [self], self)
	shot.spell = spell
	shot.quarry = &"abomination"
	return shot


## A melee spell going off: the wizard hurt if within `reach` (in front of it, within PUSH_CONE,
## when `ahead`), thrown back `throw` px/s more; every abomination within it wounded.
func _strike_round(reach: float, ahead: bool, throw: float) -> void:
	var c: Vector2 = global_position + Vector2(0, -AIM)
	var player: Player = Stage.player()
	if player != null and is_instance_valid(player) and hostile() and _meets(c, player.global_position + Vector2(0, -AIM), reach, ahead):
		var away: Vector2 = (player.global_position - global_position).normalized()
		var d: Damager = damager()
		if d != null:
			player.hurt(-1, away * (KNOCK + throw), d)
	for node: Node in get_tree().get_nodes_in_group(&"abomination"):
		var a: Node2D = node as Node2D
		if a == null or a.is_queued_for_deletion() or not _meets(c, a.global_position, reach, ahead):
			continue
		var wound: Wound = a.get_node_or_null("Wound") as Wound
		if wound != null:
			wound.hit(1, (a.global_position - global_position).normalized())


## Whether point `p` is within `reach` of `c` (and in front of it, within PUSH_CONE either side,
## when `ahead`), with no rock between.
func _meets(c: Vector2, p: Vector2, reach: float, ahead: bool) -> bool:
	var to: Vector2 = p - c
	if to.length() > reach:
		return false
	if ahead and to.length() > 30.0 and absf(angle_difference(Vector2(facing, 0).angle(), to.angle())) > PUSH_CONE + 0.5:
		return false
	return _clear(c, p)


## A lunge under way: along its floor the way it set off, fast, until it is over or meets a wall.
func _lunge_step(delta: float) -> void:
	lunging = maxf(0.0, lunging - delta)
	var hit: KinematicCollision2D = move_and_collide(Vector2(lunge_way * LUNGE_SPEED * delta, 0))
	walking = true
	walked += LUNGE_SPEED * delta
	if hit != null and absf(hit.get_normal().x) > 0.7:
		lunging = 0.0


# ------------------------------------------------------------------ staff

## A proctor's shields for those round it (see the class description).
func _shield_others(delta: float) -> void:
	cast_in -= delta * Difficulty.attack()
	if cast_in > 0.0:
		return
	cast_in = SHIELD_EVERY
	var gave: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"scholar"):
		var s: Scholar = node as Scholar
		if s == null or s == self or s.is_queued_for_deletion() or not (s.kind in [&"student", &"master"]):
			continue
		if s.global_position.distance_to(global_position) > SHIELD_REACH or Shield.of(s) != null:
			continue
		var shield: Shield = Shield.new()
		shield.name = "Shield"
		shield.hp = SHIELD_PLATES
		shield.full = SHIELD_PLATES
		s.add_child(shield)
		gave = true
	if gave:
		since_shield = 0.0
		since_cast = 0.0


## A librarian's hush: the wizard within it is drowsy (see the class description).
func _hush() -> void:
	var player: Player = Stage.player()
	if player != null and is_instance_valid(player) and player.global_position.distance_to(global_position + Vector2(0, -AIM)) <= HUSH:
		player.make_drowsy()


# ------------------------------------------------------------------ its fall

## Slain: its students scatter. Felled by the wizard, an instructor leaves its top-tier paper (once a
## room, MapInfo.instructor_fell), and a master out in the level the relic it carries (relic) or else
## its lesson (once, Lesson). One felled by abominations leaves nothing.
func _fallen() -> void:
	if kind != &"master":
		return
	for node: Node in get_tree().get_nodes_in_group(&"student"):
		var s: Scholar = node as Scholar
		if s != null and s.own_master() == self:
			s.scatter = SCATTER
			s.winding = -1.0
	if map_info == null:
		return
	if instructor():
		if wizard_blow:
			map_info.instructor_fell(hall, global_position, ability)
	elif hall < 0 and wizard_blow:
		if relic != &"":
			map_info.relic_left(global_position, relic, true)
			relic = &""
		else:
			map_info.leave_lesson(cell, global_position, ability)
