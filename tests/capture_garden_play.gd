extends TestKit
## A bot plays garden levels in the real game, to see how they go in play rather than on paper. It
## first measures what the wizard's moves do (MoveSet.measure, in the practice range), so its
## plans follow the game's own jumps, dashes and wall jumps however they are tuned. Then in each
## level it plans a way from where it stands to the way on (MoveSet.plan) and takes it a step at a
## time: walking along floors, lining up and making a measured move with exactly the presses it was
## measured with, dropping through ledges, and climbing shafts by wall jumps; after each it plans
## again from where it came down, and where a move came down somewhere else than reckoned, that is
## what it plans with from then on (MoveSet.plan's outcomes). It prints how each level went: whether it got there, how long it took,
## how many blows it took (its hearts are topped up after each, so it plays on), the stars it picked
## up, the steps it took of each kind, and where it gave up. A still of the wizard's view is saved
## now and then, to ../art-captures/riso-frames/garden_play/. A probe, not a test: doors it has no
## key for, lifts, ladders and moons are beyond it.
## With "keys=all" it comes into each level carrying a key of every colour (its keyring grown to
## hold them), as a wizard well into a run might, rather than with none (a level's doors may want a
## key from another level).
## godot --path . --windowed --fixed-fps 60 --resolution 1280x720 --script res://tests/capture_garden_play.gd -- worlds=3 first=101 rows=0,1,2 [keys=all]
## (--fixed-fps lets it run as fast as the machine allows.)
## suite: window

## The longest it plays a level, in game seconds.
const LEVEL_SECONDS: float = 150.0
## How long a walk, a line-up or a climb may take before it is given up, in physics frames.
const STEP_FRAMES: int = 240
## How close (pixels) a foe ahead must be for a cast, while walking.
const STRIKE_RANGE: float = 90.0
## A still of the view this often, in game seconds.
const STILL_EVERY: float = 20.0

var hits: int = 0
var moves: MoveSet = MoveSet.new()
## Game seconds played in the level being played.
var t: float = 0.0
var next_still: float = 0.0
var at_now: Vector2i = Vector2i.ZERO
## Whether it comes into each level with a key of every colour (keys=all).
var all_keys: bool = false


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
	all_keys = String(opts.get("keys", "")) == "all"
	await boot(first)
	await moves.measure(self)
	print(moves.describe().split("\n")[0])
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
			print("  %-22s %-9s %5.1fs  hits %2d  stars %3d  %s  %s" % [Rules.where(at), "ARRIVED" if got["arrived"] else "gave up",
					got["seconds"], got["hits"], got["stars"], got["steps"], got["note"]])
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
	player.health.max_health = 99
	player.health.health = 99
	if all_keys:
		Abilities.set_tier(player, &"keyring", Abilities.max_tier(&"keyring"))
		var colors: Array[int] = []
		for c: int in range(Rules.KEY_COLOR_COUNT):
			colors.append(c)
		player.keyring.set_all(colors)


## Play the level being played toward its way on; returns {"arrived", "seconds", "hits", "stars",
## "steps" (how many of each kind), "note"}.
func _play(at: Vector2i) -> Dictionary:
	var w: LevelGen = info.world
	var out: Dictionary = {"arrived": false, "seconds": 0.0, "hits": 0, "stars": 0, "steps": {}, "note": ""}
	if not w.exits.has(MapInfo.Exit.DEEPER):
		out["note"] = "no way on"
		return out
	var way_on: Vector2i = w.exits[MapInfo.Exit.DEEPER]
	var stars_before: int = player.coins.coins
	var outcomes: Dictionary = {}
	var steps: Dictionary = {}
	# An errand on the way (a key to fetch or a switch to throw, see _errand), and those tried.
	var errand: Dictionary = {}
	var tried: Dictionary = {}
	hits = 0
	t = 0.0
	next_still = 0.0
	at_now = at
	while t < LEVEL_SECONDS:
		await _settle_down()
		var here: Vector2i = info.cell_at(player.global_position)
		if errand.is_empty() and LevelGen.dist(here, way_on) <= 1:
			out["arrived"] = true
			break
		moves.open = _open_cells(w)
		if not errand.is_empty() and here == errand["stand"]:
			await _do_errand(errand)
			steps[errand["kind"]] = int(steps.get(errand["kind"], 0)) + 1
			errand = {}
			continue
		var path: Array[Dictionary] = []
		if errand.is_empty():
			path = moves.plan(w, here, way_on, outcomes)
		else:
			path = moves.plan(w, here, errand["stand"], outcomes, 0)
		if path.is_empty():
			errand = _errand(w, here, outcomes, tried)
			if errand.is_empty():
				out["note"] = "no way on from %s, nor a key or switch to get" % here
				break
			tried[errand["cell"]] = true
			continue
		var step: Dictionary = path[0]
		var kind: StringName = step["kind"]
		steps[kind] = int(steps.get(kind, 0)) + 1
		match kind:
			&"portal":
				await _portal(step)
			&"moon", &"air":
				# Up to a moon by a move, and on from it by the moves from mid-air that follow.
				var chain: Array[Dictionary] = [step]
				var k: int = 1
				while k < path.size() and path[k]["kind"] == &"air":
					chain.append(path[k])
					k += 1
				await _moon(chain)
			&"walk":
				await _walk_to(step["to"])
			&"drop":
				await _drop(step["to"])
			&"climb":
				await _climb(step)
			&"move":
				await _move(step)
				await _settle_down()
				var landed: Vector2i = info.cell_at(player.global_position)
				if landed != step["to"]:
					# What it really does from there, believed from now on.
					var known: Vector2i = landed if landed != step["from"] and moves.foothold(w, landed) else MoveSet.NOWHERE
					outcomes[MoveSet.key(step["from"], int(step["move"]), int(step["way"]))] = known
					steps[&"missed"] = int(steps.get(&"missed", 0)) + 1
	_release_all()
	out["seconds"] = t
	out["hits"] = hits
	out["stars"] = player.coins.coins - stars_before
	out["steps"] = steps
	if not out["arrived"] and out["note"] == "":
		out["note"] = "out of time at %s" % info.cell_at(player.global_position)
	return out


## The door and gate cells of `w` the wizard can pass now (MoveSet.open): doors opened already or
## whose key they carry, and gates that are up.
func _open_cells(w: LevelGen) -> Dictionary:
	var nodes: Dictionary = {}
	for n: Node in placed("door.tscn", true) + placed("switch_gate.tscn", true):
		nodes[n.get_meta(&"cell")] = n
	var out: Dictionary = {}
	for c: Vector2i in w.objects_of(LevelGen.Type.DOOR) + w.objects_of(LevelGen.Type.SWITCH_GATE):
		var n: Node = nodes.get(c)
		if n == null:
			out[c] = true
		elif n is SwitchGate:
			if not (n as SwitchGate).shut():
				out[c] = true
		elif player.keyring.has(int(n.get_meta(&"key_color", -1))):
			out[c] = true
	return out


## What to fetch when the way on is out of reach from `here`: the nearest key reached that the
## wizard does not carry (one the colour of a shut door first), else the nearest switch reached whose
## gate is shut; {"kind": &"key" or &"switch", "cell": where it is, "stand": the foothold to get it
## from, "color": a key's colour}, or {} when there is none not yet `tried`.
func _errand(w: LevelGen, here: Vector2i, outcomes: Dictionary, tried: Dictionary) -> Dictionary:
	var came: Dictionary = moves.reached(w, here, outcomes)
	var order: Array = came.keys()
	var shut: Dictionary = {}
	for n: Node in placed("door.tscn", true):
		shut[int(n.get_meta(&"key_color", -1))] = true
	var best: Dictionary = {}
	var rank: int = 1 << 30
	for n: Node in placed("key.tscn", true):
		var color: int = int(n.get_meta(&"key_color", -1))
		var c: Vector2i = info.cell_at((n as Node2D).global_position)
		if tried.has(c) or player.keyring.has(color):
			continue
		var r0: int = 0 if shut.has(color) else 1 << 20
		if came.has(c):
			# Stood in.
			var r: int = order.find(c) + r0
			if r < rank:
				rank = r
				best = {"kind": &"key", "cell": c, "stand": c, "color": color}
			continue
		# Passed through by a move from a foothold reached near it.
		for stand: Variant in order:
			if not stand is Vector2i or LevelGen.dist(stand, c) > 7 or not moves.foothold(w, stand):
				continue
			var r: int = order.find(stand) + r0
			if r >= rank:
				break
			var through: int = -1
			var way: int = 0
			for i: int in range(moves.moves.size()):
				for d: int in [1, -1]:
					if through < 0 and moves.sweeps(w, stand, moves.moves[i], d, c):
						through = i
						way = d
			if through >= 0:
				rank = r
				best = {"kind": &"key", "cell": c, "stand": stand, "color": color, "move": through, "way": way}
				break
	if not best.is_empty():
		return best
	for n: Node in placed("switch.tscn", true):
		var lever: Switch = n as Switch
		var c: Vector2i = n.get_meta(&"cell")
		if tried.has(c) or not came.has(c):
			continue
		var gate: Variant = null
		for g: Node in placed("switch_gate.tscn", true):
			if g.get_meta(&"cell") == lever.gate_cell:
				gate = g
		if gate == null or not (gate as SwitchGate).shut():
			continue
		var r: int = order.find(c)
		if r < rank:
			rank = r
			best = {"kind": &"switch", "cell": c, "stand": c}
	return best


## Do `errand` from where it is stood for: jump straight up for a key overhead, or throw a switch
## (the Interact button, as a press the game hears).
func _do_errand(errand: Dictionary) -> void:
	if errand["kind"] == &"key":
		if errand.has("move") and not player.keyring.has(int(errand["color"])):
			await _move({"from": errand["stand"], "move": errand["move"], "way": errand["way"]})
		return
	for pressed: bool in [true, false]:
		var press: InputEventAction = InputEventAction.new()
		press.action = &"Discover"
		press.pressed = pressed
		Input.parse_input_event(press)
		await _tick()
		await _tick()


## A physics frame of play: the clock, hearts topped up, and a still now and then.
func _tick() -> void:
	await physics_frame
	t += 1.0 / float(Engine.physics_ticks_per_second)
	if player.health.health < player.health.max_health:
		player.health.health = player.health.max_health
	if t >= next_still:
		next_still += STILL_EVERY
		save_still("garden_play/%d_%d_%03d.png" % [at_now.x, at_now.y, int(t)])


## Wait until the wizard stands still on something (or a while has gone by).
func _settle_down() -> void:
	_release_all()
	for i: int in range(STEP_FRAMES):
		if player.is_on_floor() and absf(player.velocity.x) < 1.0:
			return
		await _tick()


## Walk to the middle of cell `to` (beside the wizard), casting at foes close ahead.
func _walk_to(to: Vector2i) -> void:
	var x: float = info.cell_position(to).x
	for i: int in range(STEP_FRAMES):
		var dx: float = x - player.global_position.x
		if absf(dx) < 6.0 or not player.is_on_floor() and i > 4:
			break
		_hold("Right", dx > 0.0)
		_hold("Left", dx < 0.0)
		_strike(signf(dx))
		await _tick()
	_release_all()


## Line up in the middle of cell `c`, standing still, the dash ready if `dash`.
func _line_up(c: Vector2i, dash: bool) -> void:
	var x: float = info.cell_position(c).x
	for i: int in range(STEP_FRAMES):
		var dx: float = x - player.global_position.x
		var placed: bool = absf(dx) < 3.0
		_hold("Right", not placed and dx > 0.0)
		_hold("Left", not placed and dx < 0.0)
		var ready: bool = not dash or (not player.dash.acted and player.dash_rest <= 0.0)
		if placed and player.is_on_floor() and absf(player.velocity.x) < 1.0 and ready:
			break
		await _tick()
	_release_all()
	await _tick()


## Make move `step` (MoveSet.moves) as it was measured, until the wizard comes down again.
func _move(step: Dictionary) -> void:
	var m: Dictionary = moves.moves[int(step["move"])]
	await _line_up(step["from"], bool(m["dash"]))
	var way: float = float(step["way"])
	var left: bool = false
	var fall: int = MoveSet.last(m)
	var state: Dictionary = {}
	for f: int in range(MoveSet.FRAMES * 3):
		# Past what was measured, let go and fall straight on down (MoveSet.land).
		MoveSet.press(m["presses"], f if f <= fall else MoveSet.FRAMES + 1, way, player, state)
		await _tick()
		if not player.is_on_floor():
			left = true
		elif left:
			break
	MoveSet.press(m["presses"], MoveSet.FRAMES + 1, way)
	_release_all()


## Through a portal (the Interact button, at it), to its partner.
func _portal(step: Dictionary) -> void:
	await _line_up(step["from"], false)
	for pressed: bool in [true, false]:
		var press: InputEventAction = InputEventAction.new()
		press.action = &"Discover"
		press.pressed = pressed
		Input.parse_input_event(press)
		await _tick()
	for i: int in range(STEP_FRAMES):
		await _tick()
		if info.cell_at(player.global_position) == step["to"] and not player.has_meta(&"portal_trip"):
			break


## A move to a moon, then on from it by moves from mid-air, each made on reaching the moon before it
## (the dash it gives back ready), until the wizard comes down.
func _moon(chain: Array[Dictionary]) -> void:
	var first: Dictionary = chain[0]
	var m: Dictionary = moves.moves[int(first["move"])] if first["kind"] == &"moon" else moves.air[int(first["move"])]
	if first["kind"] == &"moon":
		await _line_up(first["from"], bool(m["dash"]))
	var k: int = 0
	var presses: Array = m["presses"]
	var way: float = float(first["way"])
	var state: Dictionary = {}
	var f: int = 0
	var left: bool = false
	for i: int in range(MoveSet.FRAMES * 3):
		MoveSet.press(presses, f, way, player, state)
		await _tick()
		f += 1
		if not player.is_on_floor():
			left = true
		elif left:
			break
		# At the moon this part was heading for: on with the next, from its first frame.
		if k < chain.size() and chain[k]["kind"] in [&"moon", &"air"] and k + 1 < chain.size():
			var moon: Vector2i = chain[k]["to"]
			if player.global_position.distance_to(info.cell_position(moon)) < moves.cell * 0.6:
				MoveSet.press(presses, MoveSet.FRAMES + 1, way)
				k += 1
				m = moves.air[int(chain[k]["move"])]
				presses = m["presses"]
				way = float(chain[k]["way"])
				state = {}
				f = 0
	MoveSet.press(presses, MoveSet.FRAMES + 1, way)
	_release_all()


## Drop through the ledge underfoot (Down and Jump together) toward `to`, under it.
func _drop(to: Vector2i) -> void:
	await _line_up(to - Vector2i(0, to.y - info.cell_at(player.global_position).y), false)
	Input.action_press("Down")
	await _tick()
	Input.action_press("Jump")
	for i: int in range(STEP_FRAMES):
		await _tick()
		if i > 6 and player.is_on_floor():
			break
		if i == 4:
			Input.action_release("Jump")
	_release_all()


## Climb a shaft by wall jumps (MoveSet.climb_step) until level with the foothold `step` leads to,
## then steer onto it.
func _climb(step: Dictionary) -> void:
	var to: Vector2i = step["to"]
	var state: Dictionary = {}
	var toward: float = 1.0 if not player.test_move(player.global_transform, Vector2(64, 0)) else -1.0
	for i: int in range(STEP_FRAMES * 3):
		if info.cell_at(player.global_position).y <= to.y and player.global_position.y < info.cell_position(to).y:
			break
		MoveSet.climb_step(player, state, toward)
		await _tick()
	_release_all()
	var x: float = info.cell_position(to).x
	for i: int in range(60):
		var dx: float = x - player.global_position.x
		_hold("Right", dx > 6.0)
		_hold("Left", dx < -6.0)
		await _tick()
		if player.is_on_floor():
			break
	_release_all()


## Cast the damage spell when a foe is close ahead of the wizard (`way` the way they go).
func _strike(way: float) -> void:
	for node: Node in get_nodes_in_group(&"hex_target"):
		var foe: Node2D = node as Node2D
		if foe == null:
			continue
		var d: Vector2 = foe.global_position - player.global_position
		if d.length() < STRIKE_RANGE and signf(d.x) == way:
			Input.action_press(Abilities.SPELL_ACTION)
			return
	Input.action_release(Abilities.SPELL_ACTION)


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for a: String in ["Left", "Right", "Up", "Down", "Jump", "Dash", Abilities.SPELL_ACTION]:
		Input.action_release(a)
