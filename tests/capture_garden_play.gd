extends TestKit
## A rough bot plays garden levels in the real game, to see how they go in play rather than on
## paper. In each level it plans a way from the way in to the way on (Reach's hops, plus chimneys
## climbed by wall jumps, see plan) and follows it with the game's own controls (walking, jumping,
## wall jumping, dashing, and the spell button when a foe is close ahead), then prints how it went:
## whether it got there, how long it took, how many blows it took (its hearts are topped up after
## each, so it plays on), the stars it picked up on the way, the wall jumps it made, and where it
## gave up. A still of the wizard's view is saved now and then, to
## ../art-captures/riso-frames/garden_play/. It is a probe, not a test: the bot is clumsy, so a
## level it fails is not a level that cannot be crossed.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_garden_play.gd -- worlds=3 first=101 rows=0,1,2
## suite: window

## The longest it plays a level, and how long it may go without getting further along its way
## before it plans again (three times) or gives up, in game seconds.
const LEVEL_SECONDS: float = 90.0
const STUCK_SECONDS: float = 8.0
## How close (pixels) a foe ahead must be for a cast.
const STRIKE_RANGE: float = 90.0
## A still of the view this often, in game seconds.
const STILL_EVERY: float = 15.0
## The widest shaft (cells) the plan climbs by wall jumps, rock on both sides: each wall jump off
## a new side lifts the wizard (Player.do_wall_jump), so a narrow shaft goes up as far as it goes.
const CHIMNEY: int = 2

var hits: int = 0


func run() -> void:
	window()
	var opts: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	var count: int = int(opts.get("worlds", 3))
	var first: int = int(opts.get("first", 101))
	var rows: Array[int] = []
	for r: String in String(opts.get("rows", "0,1,2,-1,-2")).split(",", false):
		rows.append(int(r))
	await boot(first)
	player.visual_event.connect(func(kind: StringName, _at: Vector2) -> void:
		if kind == &"hurt":
			hits += 1)
	var done: int = 0
	var played: int = 0
	for row: int in rows:
		for i: int in range(count):
			var at: Vector2i = Vector2i(first + i, row)
			await _go(at)
			var got: Dictionary = await _play(at)
			played += 1
			if got["arrived"]:
				done += 1
			print("  %-22s %-9s %5.1fs  hits %2d  stars %3d  wall jumps %2d  %s" % [Rules.where(at),
					"ARRIVED" if got["arrived"] else "gave up", got["seconds"], got["hits"], got["stars"],
					got["walls"], got["note"]])
	print("PLAYED %d levels, arrived at the way on in %d" % [played, done])
	RunState.delete_save()
	finish()


## Go straight to place `at`, arriving at its way back, and wait out the title card.
func _go(at: Vector2i) -> void:
	_release_all()
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	await until(func() -> bool: return RisoTransition.instance == null or not RisoTransition.instance.titling(), 10000)
	await frames(20)


## Play the level being played toward its way on; returns {"arrived", "seconds", "hits", "stars",
## "walls", "note"}.
func _play(at: Vector2i) -> Dictionary:
	var w: LevelGen = info.world
	var out: Dictionary = {"arrived": false, "seconds": 0.0, "hits": 0, "stars": 0, "walls": 0, "note": ""}
	if not w.exits.has(MapInfo.Exit.DEEPER):
		out["note"] = "no way on"
		return out
	var goal: Vector2i = w.exits[MapInfo.Exit.DEEPER]
	var start: Vector2i = info.cell_at(player.global_position)
	var chimneys: Dictionary = chimney_cells(w)
	var parent: Dictionary = plan(w, start, chimneys)
	if not parent.has(goal):
		out["note"] = "no way from %s to %s, even wall jumping" % [start, goal]
		return out
	var path: Array[Vector2i] = Reach.way(parent, goal)
	var cell: float = float(info.tile_map.tile_set.tile_size.x) * info.tile_map.global_scale.x
	var stars_before: int = player.coins.coins
	hits = 0
	var i: int = 1
	var t: float = 0.0
	var best: int = 0
	var since_best: float = 0.0
	var next_still: float = 1.0
	var jump_hold: int = 0
	var dashed: bool = false
	var way: float = 1.0
	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	var replans: int = 0
	while t < LEVEL_SECONDS:
		await physics_frame
		t += step
		since_best += step
		if player.health.health < player.health.max_health:
			player.health.health = player.health.max_health
		var here: Vector2i = info.cell_at(player.global_position)
		if LevelGen.dist(here, goal) <= 1:
			out["arrived"] = true
			break
		# Moved on along the path: the furthest waypoint the wizard is in (or beside, standing).
		for j: int in range(path.size() - 1, i - 1, -1):
			if here == path[j] or (j > i and LevelGen.dist(here, path[j]) <= 1 and player.is_on_floor()):
				i = mini(j + 1, path.size() - 1)
				break
		if i > best:
			best = i
			since_best = 0.0
		if since_best > STUCK_SECONDS:
			# Knocked off the path: plan again from where the wizard is, a few times.
			parent = plan(w, here, chimneys)
			if replans >= 3 or not parent.has(goal):
				out["note"] = "stuck at %s, %d of %d steps" % [here, best, path.size()]
				break
			replans += 1
			path = Reach.way(parent, goal)
			i = 1
			best = 0
			since_best = 0.0
		var target: Vector2i = path[i]
		var from: Vector2i = path[i - 1]
		var dx: float = info.cell_position(target).x - player.global_position.x
		var climbing: bool = target.y < here.y and (chimneys.has(target) or chimneys.has(here))
		if jump_hold > 0:
			jump_hold -= 1
			if jump_hold == 0:
				Input.action_release("Jump")
		if climbing:
			# Up a chimney: jump off each wall toward the other.
			if player.is_on_floor():
				if jump_hold == 0 and not Input.is_action_pressed("Jump"):
					jump_hold = 18
					Input.action_press("Jump")
				if absf(dx) > 6.0:
					way = signf(dx)
			elif player.is_on_wall():
				way = signf(player.get_wall_normal().x)
				if not Input.is_action_pressed("Jump"):
					jump_hold = 10
					Input.action_press("Jump")
					out["walls"] = int(out["walls"]) + 1
			elif absf(player.velocity.x) > 40.0:
				way = signf(player.velocity.x)
			_hold("Right", way > 0.0)
			_hold("Left", way < 0.0)
		else:
			_hold("Right", dx > 6.0)
			_hold("Left", dx < -6.0)
			var rise: int = from.y - target.y
			var gap: int = absi(target.x - from.x)
			var under: Vector2i = here + Vector2i.DOWN
			var ledge: bool = w.is_valid(under) and w.get_cell(under).type in [LevelGen.Type.PLATFORM, LevelGen.Type.MOVING_PLATFORM]
			var drop: bool = player.is_on_floor() and ledge and target.y > here.y and absf(dx) < cell * 0.6
			_hold("Down", drop)
			if drop:
				# Down through the ledge underfoot: Down and Jump together.
				if jump_hold == 0 and not Input.is_action_pressed("Jump"):
					jump_hold = 4
					Input.action_press("Jump")
			elif player.is_on_floor():
				dashed = false
				var close: bool = absf(dx) <= (float(gap) + 0.5) * cell or player.is_on_wall()
				if (rise > 0 or gap > 1) and close and jump_hold == 0 and not Input.is_action_pressed("Jump"):
					jump_hold = 18 if rise > 0 or gap > 2 else 8
					Input.action_press("Jump")
			elif not dashed and gap >= 3 and player.velocity.y > -100.0:
				Input.action_press("Dash")
				dashed = true
			elif player.is_on_wall() and rise > 0 and not Input.is_action_pressed("Jump"):
				# A wall in the way up: jump off it.
				jump_hold = 10
				Input.action_press("Jump")
				out["walls"] = int(out["walls"]) + 1
			if jump_hold == 0:
				Input.action_release("Dash")
		_strike()
		if t >= next_still:
			next_still += STILL_EVERY
			save_still("garden_play/%d_%d_%03d.png" % [at.x, at.y, int(t)])
	_release_all()
	out["seconds"] = t
	out["hits"] = hits
	out["stars"] = player.coins.coins - stars_before
	if not out["arrived"] and out["note"] == "":
		out["note"] = "out of time, %d of %d steps" % [best, path.size()]
	return out


## Open cells of shafts no wider than CHIMNEY, rock on both sides (each with another such cell
## above or below it, so a narrow passage across is not one).
static func chimney_cells(w: LevelGen) -> Dictionary:
	var narrow: Dictionary = {}
	for y: int in range(w.size.y):
		var x: int = 0
		while x < w.size.x:
			if not Reach.clear(w, Vector2i(x, y)):
				x += 1
				continue
			var run: int = 0
			while x + run < w.size.x and Reach.clear(w, Vector2i(x + run, y)):
				run += 1
			if run <= CHIMNEY:
				for k: int in range(run):
					narrow[Vector2i(x + k, y)] = true
			x += run
	var out: Dictionary = {}
	for v: Vector2i in narrow:
		if narrow.has(v + Vector2i.UP) or narrow.has(v + Vector2i.DOWN):
			out[v] = true
	return out


## Reach.tree with wall jumps: from a foothold the wizard hops (Reach.hop) to footholds or into a
## chimney; in a chimney they climb or slide to any cell of it; from a chimney cell they hop out,
## a row up and two across. Each cell reached maps to the one it was reached from.
static func plan(w: LevelGen, start: Vector2i, chimneys: Dictionary) -> Dictionary:
	var nodes: Dictionary = Reach.footholds(w)
	var parent: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var k: int = 0
	while k < queue.size():
		var a: Vector2i = queue[k]
		k += 1
		var shaft: bool = chimneys.has(a) and not nodes.has(a)
		var moon: bool = nodes.get(a, false)
		var up: int = 1 if shaft else (Reach.MOON_UP if moon else Reach.UP)
		var across: int = 2 if shaft else Reach.ACROSS
		for y: int in range(maxi(0, a.y - up), w.size.y):
			@warning_ignore("integer_division")
			var span: int = across + maxi(0, y - a.y) / 2
			for x: int in range(maxi(0, a.x - span), mini(w.size.x, a.x + span + 1)):
				var b: Vector2i = Vector2i(x, y)
				if parent.has(b) or not (nodes.has(b) or chimneys.has(b)):
					continue
				if Reach.hop(w, a, b, moon, across, up):
					parent[b] = a
					queue.append(b)
		if chimneys.has(a):
			for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if chimneys.has(a + n) and not parent.has(a + n):
					parent[a + n] = a
					queue.append(a + n)
	return parent


## Cast the damage spell when a foe is close ahead of the wizard.
func _strike() -> void:
	var ahead: float = 1.0 if Input.is_action_pressed("Right") else -1.0
	for node: Node in get_nodes_in_group(&"hex_target"):
		var foe: Node2D = node as Node2D
		if foe == null:
			continue
		var d: Vector2 = foe.global_position - player.global_position
		if d.length() < STRIKE_RANGE and signf(d.x) == ahead:
			Input.action_press(Abilities.SPELL_ACTION)
			return
	Input.action_release(Abilities.SPELL_ACTION)


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for a: String in ["Left", "Right", "Down", "Jump", "Dash", Abilities.SPELL_ACTION]:
		Input.action_release(a)
