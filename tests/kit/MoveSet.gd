class_name MoveSet
extends RefCounted
## The wizard's moves as the game itself makes them, and a planner over them, for the probes that
## play or judge levels (tests/capture_garden_play.gd, tests/dump_garden.gd). Nothing here knows how
## high the wizard jumps or how far they dash: `measure` flies the real wizard through each of
## RECIPES (what is pressed, and when) in an open hall carved out of the practice range, and keeps
## where each carried them, so a change to the wizard's moves (a jump, a dash, wall jumps, speed)
## changes the plans with it, with nothing here to update.
##
## A move starts with the wizard standing still in the middle of a cell, their dash ready. What it
## keeps (each relative to that cell; mirrored for the other way):
## - "floor": the cells that must be floor under the run-up (what they stood on before leaving it);
## - "lands": in the order they come, each place the move could come down: the cell stood in
##   ("at"), the frames it takes ("frame"), the cells the wizard's body passed through on the way
##   since the place before ("swept"), those passed going down kept apart ("falling"), as a ledge
##   only catches a wizard coming down onto it, and the rock their head struck on the way
##   ("struck").
## Each recipe is flown in the open, and again under a ceiling CEILINGS cells over where it starts
## (the garden's tunnels are low); and WALL_RECIPES are flown against a pillar of rock beside where
## they start, PILLARS cells tall, to get up onto it (wall jumps off its face among them). A move
## flown under a ceiling or against a pillar is only taken where the level has rock where the
## wizard struck it (head or side), and none in the way.
## AIR_RECIPES are flown from mid-air at rest, the dash ready: what the wizard can do on touching a
## moon (Moon), which gives the dash back. A move that passes a moon may go on from it by one.
##
## The planner (`plan`) takes a move from a foothold when its run-up has floor, and follows its
## places down in order: the move is spoilt at the first rock in what it sweeps (but rock it only
## rises into over both where it started and where it comes down: a ceiling, which bumps the head
## and no more, as far as the plan knows), and it lands at the first place with floor under it.
## Where a move made in play came down somewhere else, what it really did is told to the planner
## (`outcomes`), and believed over what it reckons. It also walks along floors, drops through ledges, and climbs
## shafts by wall jumps where `measure` found a shaft that wide can be climbed.

## The practice range's open hall, where the moves are flown: carved open, its floor at its bottom
## row, with a block of rock at its left end (MESA) to take off from, its top a cell below EDGE.
const HALL: Rect2i = Rect2i(10, 2, 60, 11)
const MESA: Rect2i = Rect2i(12, 8, 9, 5)
## Where a move starts: at the block's edge, or a few cells back on it for a run-up.
const EDGE: Vector2i = Vector2i(20, 7)
const BACK: Vector2i = Vector2i(17, 7)
## The longest a move is flown, in physics frames.
const FRAMES: int = 200
## The ceilings each recipe is flown under too: this many cells over the cell it starts in.
const CEILINGS: Array[int] = [3, 2]
## The pillars the wall recipes are flown against: this many cells tall, beside where they start.
const PILLARS: Array[int] = [1, 2, 3, 4]
## Where the moves from mid-air start (air_recipes): in the open, far from the block.
const AIR: Vector2i = Vector2i(45, 5)
## A shaft this tall (cells) climbed counts as climbable.
const CLIMBED: int = 6

## The moves: [name, start (&"edge" or &"back"), presses: [frame, action, frames held]], made by
## recipes(). Each is flown to the right, and mirrored for the left.
var moves: Array[Dictionary] = []
## The moves from mid-air (air_recipes), as moves are kept.
var air: Array[Dictionary] = []
## The widths of shaft (cells) the wizard climbs by wall jumps, and how far up each width tried
## got (cells).
var climb_widths: Array[int] = []
var climbed: Dictionary = {}
## A cell's size in px, and how long a move may take at most (frames).
var cell: float = 128.0


## What is tried: jumps held short, mid and long, from standing or with the way held, with no dash,
## or a dash on the way, up, or up the way at a few points; jumps up first and over later; running
## jumps; walking off an edge, with or without a dash; and stepping off one and letting go.
static func recipes() -> Array[Array]:
	var out: Array[Array] = []
	for hold: int in [4, 10, 30]:
		for steer: bool in [false, true]:
			var base: Array = [[0, "Jump", hold]]
			if steer:
				base.append([0, "Right", FRAMES])
			out.append(["jump %d%s" % [hold, " right" if steer else ""], &"edge", base])
			for at: int in [8, 16, 24]:
				if steer:
					out.append(["jump %d right, dash right at %d" % [hold, at], &"edge", base + [[at, "Dash", 2]]])
					out.append(["jump %d right, dash up-right at %d" % [hold, at], &"edge", base + [[at - 1, "Up", 20], [at, "Dash", 2]]])
				out.append(["jump %d%s, dash up at %d" % [hold, " right" if steer else "", at], &"edge", base + [[at - 1, "Up", 20], [at, "Dash", 2]]])
	# Up first, then over: the way held only once high (over a wall beside the wizard).
	for steer: int in [12, 24, 36]:
		var base: Array = [[0, "Jump", 30], [steer, "Right", FRAMES]]
		out.append(["jump 30, right from %d" % steer, &"edge", base])
		for at: int in [16, 24]:
			out.append(["jump 30, dash up at %d, right from %d" % [at, steer], &"edge", base + [[at - 1, "Up", 20], [at, "Dash", 2]]])
	for run: int in [10, 22]:
		for hold: int in [10, 30]:
			var base: Array = [[0, "Right", FRAMES], [run, "Jump", hold]]
			out.append(["run %d, jump %d" % [run, hold], &"back", base])
			out.append(["run %d, jump %d, dash right" % [run, hold], &"back", base + [[run + 16, "Dash", 2]]])
			out.append(["run %d, jump %d, dash up-right" % [run, hold], &"back", base + [[run + 15, "Up", 20], [run + 16, "Dash", 2]]])
	out.append(["walk off", &"edge", [[0, "Right", FRAMES]]])
	# A step off the edge, then let go: down a narrow shaft.
	for hold: int in [14, 20, 28]:
		out.append(["step off %d" % hold, &"edge", [[0, "Right", hold]]])
	for at: int in [12, 24]:
		out.append(["walk off, dash right at %d" % at, &"edge", [[0, "Right", FRAMES], [at, "Dash", 2]]])
	return out


## What is tried against a pillar beside the wizard: jumps into it with the way held, a dash up or
## up the way at a few points, with and without a wall jump off its face (the first in a flight
## lifts the wizard; "Wall jump" presses Jump at the first wall touched from its frame on).
static func wall_recipes() -> Array[Array]:
	var out: Array[Array] = []
	for wall: bool in [false, true]:
		var base: Array = [[0, "Jump", 30], [0, "Right", FRAMES]]
		if wall:
			base.append([2, "Wall jump", 40])
		var what: String = "jump 30 right%s" % (", wall jump" if wall else "")
		out.append([what, &"edge", base])
		for at: int in [12, 20, 28, 36]:
			out.append(["%s, dash up-right at %d" % [what, at], &"edge", base + [[at - 1, "Up", 20], [at, "Dash", 2]]])
			out.append(["%s, dash up at %d" % [what, at], &"edge", base + [[at - 1, "Up", 20], [at - 1, "Right", -1], [at, "Dash", 2]]])
	return out


## What is tried from mid-air, the dash ready (a moon just touched): a dash up, up the way, or the
## way, the way held after or not.
static func air_recipes() -> Array[Array]:
	return [
		["dash up", &"air", [[0, "Up", 20], [0, "Dash", 2]]],
		["dash up, then right", &"air", [[0, "Up", 20], [0, "Dash", 2], [16, "Right", FRAMES]]],
		["dash up-right", &"air", [[0, "Up", 20], [0, "Right", FRAMES], [0, "Dash", 2]]],
		["dash up-right, let go", &"air", [[0, "Up", 20], [0, "Right", 16], [0, "Dash", 2]]],
		["dash right", &"air", [[0, "Right", FRAMES], [0, "Dash", 2]]],
		["dash right, let go", &"air", [[0, "Right", 16], [0, "Dash", 2]]],
	]


# ------------------------------------------------------------------ measuring

## Fly every recipe in the practice range under the run `kit` has booted, and climb shafts of a
## few widths; the wizard is left there (the caller goes back where it was).
func measure(kit: TestKit) -> void:
	var info: MapInfo = kit.info
	info.coord = Worlds.side_at(Worlds.kind_of(PracticeRange), Vector2i(info.coord.x, 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await kit.settle()
	cell = float(info.tile_map.tile_set.tile_size.x) * info.tile_map.global_scale.x
	for n: Node in info.map_elements.get_children():
		n.process_mode = Node.PROCESS_MODE_DISABLED
		if n is Node2D:
			(n as Node2D).visible = false
	kit.player.health.max_health = 999
	kit.player.health.health = 999
	moves.clear()
	for ceiling: int in [0] + CEILINGS:
		_carve(info, HALL, false)
		_carve(info, MESA, true)
		if ceiling > 0:
			_carve(info, Rect2i(HALL.position.x, EDGE.y - ceiling, HALL.size.x, 1), true)
		await kit.frames(3)
		for r: Array in recipes():
			var m: Dictionary = await _fly(kit, r)
			if ceiling > 0:
				m["name"] = "%s, under %d" % [m["name"], ceiling]
			if not (m["lands"] as Array).is_empty():
				moves.append(m)
	air.clear()
	_carve(info, HALL, false)
	await kit.frames(3)
	for r: Array in air_recipes():
		air.append(await _fly(kit, r))
	for tall: int in PILLARS:
		_carve(info, HALL, false)
		_carve(info, MESA, true)
		_carve(info, Rect2i(EDGE.x + 1, EDGE.y + 1 - tall, 1, HALL.end.y - EDGE.y - 1 + tall), true)
		await kit.frames(3)
		for r: Array in wall_recipes():
			var m: Dictionary = await _fly(kit, r)
			m["name"] = "%s, pillar %d" % [m["name"], tall]
			if not (m["lands"] as Array).is_empty():
				moves.append(m)
	climb_widths.clear()
	for width: int in [1, 2, 3]:
		_carve(info, HALL, false)
		_carve(info, Rect2i(40, HALL.position.y + 1, 1, HALL.size.y - 1), true)
		_carve(info, Rect2i(41 + width, HALL.position.y + 1, 1, HALL.size.y - 1), true)
		await kit.frames(3)
		var rose: float = await _climb(kit, Vector2i(41, HALL.end.y - 1))
		climbed[width] = rose
		if rose >= float(CLIMBED):
			climb_widths.append(width)
	kit.still()
	for a: String in ["Left", "Right", "Up", "Down", "Jump", "Dash"]:
		Input.action_release(a)


## Make every cell of `r` rock or open air.
static func _carve(info: MapInfo, r: Rect2i, rock: bool) -> void:
	var tm: TileMap = info.tile_map
	var from: Vector2i = tm.get_used_cells(0)[0]
	var src: int = tm.get_cell_source_id(0, from)
	var atlas: Vector2i = tm.get_cell_atlas_coords(0, from)
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			if rock:
				tm.set_cell(0, Vector2i(x, y), src, atlas)
			else:
				tm.erase_cell(0, Vector2i(x, y))


## Stand the wizard still in the middle of cell `c`, their dash ready.
static func stand(kit: TestKit, c: Vector2i) -> void:
	var player: Player = kit.player
	player.set_physics_process(false)
	kit.still()
	player.global_position = kit.info.cell_position(c)
	CameraControl.snap(player)
	player.set_physics_process(true)
	for i: int in range(30):
		await kit.physics_frame
	player.dash_rest = 0.0
	player.dash.refresh()
	await kit.physics_frame


## Fly recipe `r`, and keep what it did (see the class description).
func _fly(kit: TestKit, r: Array) -> Dictionary:
	var info: MapInfo = kit.info
	var player: Player = kit.player
	var start: Vector2i = EDGE if r[1] == &"edge" else (BACK if r[1] == &"back" else AIR)
	if r[1] == &"air":
		# Held still in mid-air, the dash ready, and let go.
		player.set_physics_process(false)
		kit.still()
		player.global_position = info.cell_position(start)
		CameraControl.snap(player)
		player.dash_rest = 0.0
		player.dash.refresh()
		player.set_physics_process(true)
	else:
		await stand(kit, start)
	var presses: Array = r[2]
	# It stands on the floor under it; the run-up may cross more.
	var floors: Dictionary = {} if r[1] == &"air" else {Vector2i(0, 1): true}
	var lands: Array[Dictionary] = []
	var swept: Dictionary = {}
	var falling: Dictionary = {}
	var struck: Dictionary = {}
	var left_floor: bool = false
	var feet: float = player._feet_y()
	var dash: bool = presses.any(func(p: Array) -> bool: return p[1] == "Dash")
	var state: Dictionary = {}
	for f: int in range(FRAMES):
		press(presses, f, 1.0, player, state)
		await kit.physics_frame
		var now: float = player._feet_y()
		# Going down: the feet lower than a frame ago, or just come down on something (which
		# stops them, its fall spent).
		var down: bool = now > feet + 0.01 or (left_floor and player.is_on_floor())
		if player.is_on_floor() and not left_floor:
			# What is under the middle, if it is the floor (the middle passes over the edge before
			# the body leaves it).
			var under: Vector2i = info.cell_at(Vector2(player.global_position.x, now + 4.0))
			if info.solid_at(info.cell_position(under)):
				floors[under - start] = true
		elif not player.is_on_floor():
			left_floor = true
		# The rows whose tops the feet passed going down, once off the run-up: a place to come down
		# on each.
		if down and left_floor:
			for row: int in range(info.cell_at(Vector2(0, feet)).y, info.cell_at(Vector2(0, now + 2.0)).y + 1):
				var top: float = info.cell_position(Vector2i(0, row)).y - cell * 0.5
				if feet <= top + 1.0 and now >= top - 1.0:
					var at: Vector2i = Vector2i(info.cell_at(player.global_position).x, row - 1) - start
					if lands.is_empty() or lands[-1]["at"] != at:
						lands.append({"at": at, "frame": f, "swept": swept.keys(), "falling": falling.keys(), "struck": struck.keys()})
						swept = {}
						falling = {}
						struck = {}
		for c: Vector2i in body_cells(info, player):
			var rel: Vector2i = c - start
			swept[rel] = true
			if down:
				falling[rel] = true
		if player.is_on_ceiling():
			for c: Vector2i in body_cells(info, player):
				if info.solid_at(info.cell_position(c + Vector2i.UP)):
					struck[c - start + Vector2i.UP] = true
		if player.is_on_wall():
			var side: Vector2i = Vector2i(-signi(roundi(player.get_wall_normal().x)), 0)
			for c: Vector2i in body_cells(info, player):
				if info.solid_at(info.cell_position(c + side)):
					struck[c - start + side] = true
		feet = now
		if left_floor and player.is_on_floor():
			break
	press(presses, FRAMES + 1, 1.0, player, state)
	return {"name": r[0], "start": r[1], "presses": presses, "dash": dash, "floor": floors.keys(), "lands": lands}


## The cells the wizard's body is in now.
static func body_cells(info: MapInfo, player: Player) -> Array[Vector2i]:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D") as CollisionShape2D
	var r: Rect2 = shape.shape.get_rect()
	var box: Rect2 = Rect2(shape.global_transform * r.position, r.size * shape.global_transform.get_scale()).grow(-2.0)
	var a: Vector2i = info.cell_at(box.position)
	var b: Vector2i = info.cell_at(box.end)
	var out: Array[Vector2i] = []
	for x: int in range(a.x, b.x + 1):
		for y: int in range(a.y, b.y + 1):
			out.append(Vector2i(x, y))
	return out


## Press and let go of what `presses` says at frame `f` of a move, the way mirrored for `way` -1:
## each [frame, action, frames held] (held -1: let go of it then). "Wall jump" presses Jump at the
## first wall `player` touches in its frames (letting go a frame first if it is down), once.
static func press(presses: Array, f: int, way: float, player: Player = null, state: Dictionary = {}) -> void:
	for p: Array in presses:
		var action: String = p[1]
		if way < 0.0 and action == "Right":
			action = "Left"
		var from: int = int(p[0])
		var held: int = int(p[2])
		if action == "Wall jump":
			if f >= from and f < from + held and player != null and not state.has("walled") and player.is_on_wall() and not player.is_on_floor():
				if Input.is_action_pressed("Jump"):
					Input.action_release("Jump")
				else:
					Input.action_press("Jump")
					state["walled"] = f
			if state.get("walled", -100) == f - 8:
				Input.action_release("Jump")
			continue
		if held < 0:
			if from == f:
				Input.action_release(action)
			continue
		if from == f:
			Input.action_press(action)
		if from + held == f or (f > FRAMES and Input.is_action_pressed(action)):
			Input.action_release(action)
	if f > FRAMES:
		for a: String in ["Left", "Right", "Up", "Jump", "Dash"]:
			Input.action_release(a)


## Climb the shaft whose floor cell is `c` by wall jumps, from wall to wall (see climb_step); how
## many cells the feet rose.
static func _climb(kit: TestKit, c: Vector2i) -> float:
	await stand(kit, c)
	var player: Player = kit.player
	var start: float = player._feet_y()
	var top: float = 0.0
	var state: Dictionary = {}
	for f: int in range(600):
		climb_step(player, state, 1.0)
		await kit.physics_frame
		top = maxf(top, start - player._feet_y())
	for a: String in ["Left", "Right", "Jump"]:
		Input.action_release(a)
	return top / float(kit.info.tile_map.tile_set.tile_size.x * kit.info.tile_map.global_scale.x)


## One frame of climbing a shaft by wall jumps (its `state` kept between frames, `toward` the way to
## set off): jump off the floor toward a wall, then jump again at each wall of the other side from
## the last. The jump is pressed still holding toward the wall (the game finds the wall by that
## frame's own push against it), and only the frame after does the wizard steer for the far wall.
## The button is kept down for the lift (letting go cuts a rising jump short) until the next wall is
## a frame off, then let go, so the press at the wall is a new one.
static func climb_step(player: Player, state: Dictionary, toward: float) -> void:
	var way: float = float(state.get("way", toward))
	if state.has("turn"):
		way = float(state["turn"])
		state.erase("turn")
	var side: float = signf(player.get_wall_normal().x) if player.is_on_wall() else 0.0
	var last: float = float(state.get("side", 0.0))
	if player.is_on_floor() and not Input.is_action_pressed("Jump"):
		Input.action_press("Jump")
		state["side"] = 0.0
	elif side != 0.0 and side != last and not Input.is_action_pressed("Jump"):
		Input.action_press("Jump")
		state["side"] = side
		state["turn"] = side
	elif Input.is_action_pressed("Jump") and not player.is_on_floor() and player.test_move(player.global_transform, Vector2(way * (absf(player.velocity.x) / float(Engine.physics_ticks_per_second) + 2.0), 0.0)):
		# The next wall is a frame off: let go now, to press anew on it.
		Input.action_release("Jump")
	state["way"] = way
	Input.action_press("Right" if way > 0.0 else "Left")
	Input.action_release("Left" if way > 0.0 else "Right")


## What was measured, a line a move.
func describe() -> String:
	var lines: Array[String] = ["%d moves and %d from mid-air, shafts climbed %s cells wide (by width, cells risen: %s)" % [moves.size(), air.size(), climb_widths, climbed]]
	for m: Dictionary in moves:
		var ats: Array[String] = []
		for l: Dictionary in m["lands"]:
			ats.append(str(l["at"]))
		lines.append("  %-36s floor %s, lands %s" % [m["name"], m["floor"], ", ".join(ats)])
	return "\n".join(lines)


# ------------------------------------------------------------------ planning

## Doors and gates the planner may pass (cells, as keys): doors the wizard has the key for or has
## opened, gates that are up. The rest are shut. Set by whoever plans in play; empty, every door and
## gate is shut.
var open: Dictionary = {}


## Whether the wizard's body can be in `v` of `w`: in the level, and not rock, a shut door or gate
## (see open), or thorns (but those on a timer).
func clear(w: LevelGen, v: Vector2i) -> bool:
	if not w.is_valid(v):
		return false
	if open.has(v):
		return true
	# Thorns on a timer (Spikes) go down now and then: passed, a blow risked (thorns on a switch
	# are shut, as a gate is).
	if w.get_cell(v).type == LevelGen.Type.SPIKES and Reach.timed(w.get_cell(v)):
		return true
	return not w.get_cell(v).type in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR,
		LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.EXAM_DOOR, LevelGen.Type.LIGHT_GATE]


## Whether `v` holds the wizard up: rock, a ledge, a shut door, or the rock round the level.
func holds(w: LevelGen, v: Vector2i) -> bool:
	if not w.is_valid(v):
		return v.y >= w.size.y
	if open.has(v):
		return false
	return w.get_cell(v).type in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.PLATFORM,
		LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE]


## Where the wizard can stand in `w`.
func foothold(w: LevelGen, v: Vector2i) -> bool:
	return clear(w, v) and holds(w, v + Vector2i.DOWN)


## The steps from where the wizard stands in `w` to the first foothold within `near` cells of
## `goal`: each {"kind": &"walk", &"move", &"drop" or &"climb", "from", "to", "move": index into
## moves, "way": +1 or -1}; [] when none is found. `outcomes` holds what moves made in play really
## did, by key(from, move, way): the cell they came down in, or NOWHERE for one that went nowhere.
func plan(w: LevelGen, from: Vector2i, goal: Vector2i, outcomes: Dictionary = {}, near: int = 1) -> Array[Dictionary]:
	var came: Dictionary = reached(w, from, outcomes, goal, near)
	var end: Variant = came.get(&"end")
	if end == null:
		return []
	var out: Array[Dictionary] = []
	var at: Vector2i = end
	while at != from:
		var step: Dictionary = came[at]
		out.push_front(step)
		at = step["from"]
	return out


## Every foothold reached from `from` in `w`, nearest first (in steps), each mapped to the step that
## reached it ({} for `from`); with a `goal`, only until a foothold within `near` of it, kept as
## &"end".
func reached(w: LevelGen, from: Vector2i, outcomes: Dictionary = {}, goal: Vector2i = NOWHERE, near: int = 1) -> Dictionary:
	var chimneys: Dictionary = shafts(w)
	var came: Dictionary = {from: {}}
	var queue: Array[Vector2i] = [from]
	var k: int = 0
	while k < queue.size():
		var a: Vector2i = queue[k]
		k += 1
		if goal != NOWHERE and LevelGen.dist(a, goal) <= near:
			came[&"end"] = a
			break
		for step: Dictionary in steps_from(w, a, chimneys, outcomes):
			var b: Vector2i = step["to"]
			if not came.has(b):
				came[b] = step
				queue.append(b)
	return came


## A move made in play that came down nowhere new (see plan).
const NOWHERE: Vector2i = Vector2i(-1, -1)


## The key a move's outcome is kept by (see plan).
static func key(from: Vector2i, move: int, way: int) -> String:
	return "%s|%d|%d" % [from, move, way]


## Every foothold one step from foothold `a` (see plan).
func steps_from(w: LevelGen, a: Vector2i, chimneys: Dictionary = {}, outcomes: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# At a moon in mid-air: on by a move from mid-air (to a floor, or another moon).
	if moon_at(w, a):
		for i: int in range(air.size()):
			for way: int in [1, -1]:
				var to: Variant = land(w, a, air[i], way)
				if to != null and to != a:
					out.append({"kind": &"air", "from": a, "to": to, "move": i, "way": way})
				var moon: Variant = moon_on(w, a, air[i], way)
				if moon != null:
					out.append({"kind": &"air", "from": a, "to": moon, "move": i, "way": way})
		return out
	# Through a portal, to its partner.
	if w.get_cell(a).type == LevelGen.Type.PORTAL and w.get_cell(a).extra_info is Vector2i and foothold(w, w.get_cell(a).extra_info):
		out.append({"kind": &"portal", "from": a, "to": w.get_cell(a).extra_info, "way": 0})
	for way: int in [1, -1]:
		var side: Vector2i = a + Vector2i(way, 0)
		if foothold(w, side):
			out.append({"kind": &"walk", "from": a, "to": side, "way": way})
	for i: int in range(moves.size()):
		var m: Dictionary = moves[i]
		for way: int in [1, -1]:
			var known: Variant = outcomes.get(key(a, i, way))
			var to: Variant = known if known != null else land(w, a, m, way)
			if to == NOWHERE or to == a:
				continue
			if to != null:
				out.append({"kind": &"move", "from": a, "to": to, "move": i, "way": way})
			# On its way, a moon to go on from (see steps_from at a moon).
			var moon: Variant = moon_on(w, a, m, way)
			if moon != null:
				out.append({"kind": &"moon", "from": a, "to": moon, "move": i, "way": way})
	# Down through a ledge, to the first floor under it.
	if w.is_valid(a + Vector2i.DOWN) and w.get_cell(a + Vector2i.DOWN).type == LevelGen.Type.PLATFORM:
		var c: Vector2i = a + Vector2i.DOWN
		while w.is_valid(c) and (clear(w, c) or w.get_cell(c).type == LevelGen.Type.PLATFORM) and c.y < w.size.y:
			if c != a + Vector2i.DOWN and foothold(w, c):
				out.append({"kind": &"drop", "from": a, "to": c, "way": 0})
				break
			c += Vector2i.DOWN
	# Up a shaft by wall jumps, out at its top: one the wizard stands in, or one a jump straight up
	# takes them into (its foot no higher over them than a plain jump lifts them, and a row more).
	var entry: Variant = null
	for k: int in range(0, jump_rows() + 2):
		var c: Vector2i = a + Vector2i(0, -k)
		if k > 0 and not clear(w, c):
			break
		if chimneys.has(c):
			entry = c
			break
	if entry != null:
		var top: Vector2i = entry
		while chimneys.has(top + Vector2i.UP):
			top += Vector2i.UP
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(2, -1), Vector2i(-2, -1), Vector2i(0, -1)]:
			var b: Vector2i = top + d
			if b != a and foothold(w, b):
				out.append({"kind": &"climb", "from": a, "to": b, "way": signi(d.x)})
	return out


## Whether `v` of `w` holds a moon in mid-air.
func moon_at(w: LevelGen, v: Vector2i) -> bool:
	return w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.MOON and not foothold(w, v)


## Whether move `m`, made from `a` toward `way`, passes through cell `target` (a key to take on the
## way) before it comes down or is spoilt.
func sweeps(w: LevelGen, a: Vector2i, m: Dictionary, way: int, target: Vector2i) -> bool:
	var flip: Callable = func(v: Vector2i) -> Vector2i: return a + Vector2i(v.x * way, v.y)
	for f: Vector2i in m["floor"]:
		if not holds(w, flip.call(f)):
			return false
	for l: Dictionary in m["lands"]:
		var over: int = mini(0, (l["at"] as Vector2i).y)
		for s: Vector2i in l["swept"]:
			var c: Vector2i = flip.call(s)
			if c == target:
				return true
			if not clear(w, c) and not (s.y < over and not (l["falling"] as Array).has(s)):
				return false
		if foothold(w, flip.call(l["at"])):
			return false
	return false


## The first moon move `m`, made from `a` toward `way`, passes through before it comes down or is
## spoilt, or null.
func moon_on(w: LevelGen, a: Vector2i, m: Dictionary, way: int) -> Variant:
	var flip: Callable = func(v: Vector2i) -> Vector2i: return a + Vector2i(v.x * way, v.y)
	for f: Vector2i in m["floor"]:
		if not holds(w, flip.call(f)):
			return null
	for l: Dictionary in m["lands"]:
		var over: int = mini(0, (l["at"] as Vector2i).y)
		for s: Vector2i in l["swept"]:
			var c: Vector2i = flip.call(s)
			if c != a and moon_at(w, c):
				return c
			if not clear(w, c) and not (s.y < over and not (l["falling"] as Array).has(s)):
				return null
		if foothold(w, flip.call(l["at"])):
			return null
	return null


## How many rows up a plain jump (no dash, no way held) takes the wizard, as measured.
func jump_rows() -> int:
	var rows: int = 0
	for m: Dictionary in moves:
		if m["dash"] or (m["presses"] as Array).any(func(p: Array) -> bool: return p[1] != "Jump"):
			continue
		for l: Dictionary in m["lands"]:
			rows = maxi(rows, -(l["at"] as Vector2i).y)
	return rows


## Where move `m`, made from foothold `a` toward `way`, comes down in `w`, or null if its run-up
## has no floor or rock spoils it first.
func land(w: LevelGen, a: Vector2i, m: Dictionary, way: int) -> Variant:
	var flip: Callable = func(v: Vector2i) -> Vector2i: return a + Vector2i(v.x * way, v.y)
	for f: Vector2i in m["floor"]:
		if not holds(w, flip.call(f)):
			return null
	for l: Dictionary in m["lands"]:
		var falling: Array = l["falling"]
		# Rock risen into over both the start and this place: a ceiling, bumped.
		var over: int = mini(0, (l["at"] as Vector2i).y)
		for s: Vector2i in l.get("struck", []):
			if clear(w, flip.call(s)):
				return null
		for s: Vector2i in l["swept"]:
			var c: Vector2i = flip.call(s)
			if clear(w, c) or (s.y < over and not falling.has(s)):
				continue
			# A ledge only stops the wizard coming down onto it.
			if w.is_valid(c) and w.get_cell(c).type == LevelGen.Type.PLATFORM and not falling.has(s):
				continue
			return null
		var at: Vector2i = flip.call(l["at"])
		if clear(w, at) and holds(w, at + Vector2i.DOWN):
			return at if at != a else null
	# Deeper than the hall measured: past its last place the presses are let go (see `last`), and
	# the wizard falls on down from there to the first floor under them.
	var lands: Array = m["lands"]
	if lands.is_empty():
		return null
	var c: Vector2i = flip.call((lands.back() as Dictionary)["at"])
	while true:
		c += Vector2i.DOWN
		if not clear(w, c):
			return null
		if holds(w, c + Vector2i.DOWN):
			return c
	return null


## The frame of move `m` after which its presses are let go and the wizard falls straight on down
## (its last place measured, the hall's floor; see land).
static func last(m: Dictionary) -> int:
	var lands: Array = m["lands"]
	return int((lands.back() as Dictionary)["frame"]) if not lands.is_empty() else FRAMES


## The open cells of shafts the wizard can climb by wall jumps (no wider than the widest measured
## to climb, rock either side), each with another such cell over or under it.
func shafts(w: LevelGen) -> Dictionary:
	var widest: int = 0
	for width: int in climb_widths:
		widest = maxi(widest, width)
	var narrow: Dictionary = {}
	if widest == 0:
		return narrow
	for y: int in range(w.size.y):
		var x: int = 0
		while x < w.size.x:
			if not clear(w, Vector2i(x, y)):
				x += 1
				continue
			var run: int = 0
			while x + run < w.size.x and clear(w, Vector2i(x + run, y)):
				run += 1
			if run <= widest and climb_widths.has(run):
				for i: int in range(run):
					narrow[Vector2i(x + i, y)] = true
			x += run
	var out: Dictionary = {}
	for v: Vector2i in narrow:
		if narrow.has(v + Vector2i.UP) or narrow.has(v + Vector2i.DOWN):
			out[v] = true
	return out
