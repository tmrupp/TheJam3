extends Control

class_name MapInfo
## The place being played, and the run around it. Three parts do the work: LevelGen lays a level
## out from its seed, RunState keeps what the run remembers (each place's LevelRecord, the lantern
## to come back to, the ghost) and saves it, and LevelLoader (`loader`) puts the place in the scene.
## This node holds the place being played (`coord`, its definition `here`, its layout `world`),
## moves between places (travel), and does what a change in the record means in the scene: a door
## opening, a bell ringing a bridge into place, a secret room crumbling, the wizard dying. The rules
## that hold across the run (level_seed, prices, rarities) are in Rules.

## A level's ways out. Deeper and back move along the seed's column; left and right step to the
## neighbouring seed at the same depth, as if a run had started there; a level a side world leads
## into has an ordinary way up as well (RETURN). Where each leads is up to the place's definition
## (NextWorldDef.lead); doors into side worlds are numbered from Worlds.DOOR_BASE.
const Exit = Ways.Exit

## Debug runs (from the start menu): every exit is generated right by the spawn, and the run
## starts with DEBUG_STARS. Saved with the run and shown in the HUD.
static var debug: bool:
	get:
		return Dev.debug
	set(on):
		Dev.debug = on
## Whether this is a demo build: an export with the "demo" feature (an export preset's custom
## feature), which also plays the demo's band layout (Bands.DEMO). Tests set it to try one.
static var demo_build: bool:
	get:
		return Dev.demo_build
	set(on):
		Dev.demo_build = on
## Whether this is a demo build kept for testing the demo: an export with the "demo_dev" feature as
## well as "demo" (the "Windows Demo (dev tools)" preset, into builds/demo-dev). It plays the demo
## all the same, with the developer's tools left in. Tests set it to try one.
static var demo_dev: bool:
	get:
		return Dev.demo_dev
	set(on):
		Dev.demo_dev = on


## Whether the developer's tools are at hand: the start menu's debug toggle (debug runs), the F7
## panel and F8's realms (RisoPrint), and going back a level at a key (Debug-Back). A demo build has
## none of them, so its players get the game alone, on Normal (Difficulty.DEMO_DEFAULT); a demo
## build for testing (demo_dev) keeps them.
static func dev_tools() -> bool:
	return Dev.dev_tools()
const DEBUG_STARS: int = 9999

static var instance: MapInfo

@onready var wfc: WaveFunctionCollapse = $"../../WaveFunctionCollapse"
@onready var tile_map: TileMap = $"../../TileMap"
@onready var main: Node = Stage.main()
var player: Player

## What the run remembers (see RunState), and what puts places in the scene (see LevelLoader).
var run: RunState = RunState.new()
var loader: LevelLoader
## The institute as it is played (InstitutePlay): its timetable, classes, papers and departments.
var institute: InstitutePlay = InstitutePlay.new(self)

## The place being played: for a level x is the seed and y the depth (see Worlds for the rest).
var coord: Vector2i = Vector2i.ZERO
## Its definition (set as it loads): where its exits lead, what they cost, how it prints.
var here: NextWorldDef = NextWorldDef.new().setup(Vector2i.ZERO)
## Its layout, once loaded.
var world: LevelGen
## Everything placed in it (see LevelLoader.build).
var map_elements: Node:
	get:
		return loader.map_elements if loader != null else null
## The exit the player arrives at; -1 starts a run, -2 respawns at a lantern.
var arrival: int = -1
## Where to arrive when `arrival` is -3 (a tier III rift from another level).
var arrival_pos: Vector2 = Vector2.ZERO
var travelling: bool = false
## Where the wizard comes back to (the last lantern lit), and the ghost of their last death.
var respawn_marker: Node2D
var ghost_node: Node2D
const GHOST: String = "res://prefabs/corpse.tscn"
## Seconds left on the end-of-run card (0 while playing).
var run_ending: float = 0.0
const RUN_END_SECONDS: float = 3.0
## Whether the run is won (win_run): its card shows until a press, made after it has shown for
## WIN_HOLD seconds (so a press in the fight's last moment does not skip it), then the start menu.
## How long the card has shown (won_for), and whether a press has come for it.
var won: bool = false
const WIN_HOLD: float = 1.5
var won_for: float = 0.0
var _won_pressed: bool = false
## A boss's trophy (Trophy), and where it drops beside where its boss fell (trophy_spot): the cells
## to either side tried in turn, else this far over the spot itself.
const TROPHY: String = "res://prefabs/trophy.tscn"
const TROPHY_SIDES: Array[int] = [1, -1, 2, -2]
const TROPHY_OVER: Vector2 = Vector2(0, -110)


func _enter_tree() -> void:
	instance = self
	if loader == null:
		loader = LevelLoader.new(self)
		loader.ready_to_build.connect(_level_ready)
		add_child(loader)


func _exit_tree() -> void:
	# Leaving the scene (back to the start menu): a change not yet written is written now.
	if _unsaved:
		save_now()
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


## The one place the autosave is written: once a frame at most, however many changes asked for it
## (save_run).
func _process (_delta: float) -> void:
	if _unsaved:
		_write_run()


## The sigil of the thing `node` in the level being played (by its cell, LevelGen.sigil_at), or -1
## if it has none.
static func sigil_of (node: Node) -> int:
	var info: MapInfo = instance
	if info == null or info.world == null or node == null or not node.has_meta(&"cell"):
		return -1
	return info.world.sigil_at(node.get_meta(&"cell"))


## The wizard, found in the scene the first time it is wanted.
func wizard() -> Player:
	if player == null:
		player = Stage.player()
	return player


## The camera following the wizard, or null.
func camera() -> Camera2D:
	return Stage.camera()

# ------------------------------------------------------------------ the record

## The record of place `at` (the place being played, unless given).
func record (at: Vector2i = coord) -> LevelRecord:
	return run.record(at)

func mark_taken (node: Node) -> void:
	if node.has_meta(&"cell"):
		record().taken[node.get_meta(&"cell")] = true

func mark_opened (node: Node) -> void:
	if node.has_meta(&"cell"):
		record().opened[node.get_meta(&"cell")] = true

## An enemy the hex bolt destroyed: gone until the player dies.
func mark_slain (node: Node) -> void:
	if node.has_meta(&"cell"):
		record().slain[node.get_meta(&"cell")] = true

## A key was grabbed. A generated key is recorded as taken; a dropped one leaves the record.
## The key the player was carrying (`had`, -1 for none) is left where the new one was.
func key_taken (key: Node2D, had: int) -> void:
	var rec: LevelRecord = record()
	if key.has_meta(&"dropped_id"):
		rec.dropped.erase(int(key.get_meta(&"dropped_id")))
	else:
		mark_taken(key)
	if had < 0:
		return
	var id: int = rec.drop_key(key.position, had)
	_spawn_dropped_key.call_deferred(id, key.position, had)
	save_run()

## How far (cells) from the shrine a skeleton key it sold is laid, at least (where the level allows).
const SOLD_KEY_APART: int = 10
const SOLD_KEY_DEAL: int = Salts.MAP_INFO_SOLD_KEY * Salts.STRIDE
## A shrine sold a skeleton key: it is laid on a floor of this level, dealt by the level seed, at
## least SOLD_KEY_APART cells from the shrine where there is such a floor (never in a vault or a
## barrier's pocket, LevelGen.floors_proper). It is kept as a dropped key (the record keeps it until
## taken, and the map shows it). Returns where.
func lay_sold_skeleton () -> Vector2:
	var floors: Array[Vector2i] = world.floors_proper()
	var far: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, world.shrine) >= SOLD_KEY_APART)
	var pool: Array[Vector2i] = far if not far.is_empty() else floors
	var at: Vector2i = pool[Rules.level_seed(Rules.level_seed(coord.x, coord.y), SOLD_KEY_DEAL) % pool.size()] if not pool.is_empty() else world.shrine
	var pos: Vector2 = cell_position(at)
	var id: int = record().drop_key(pos, KeyRing.SKELETON)
	_spawn_dropped_key(id, pos, KeyRing.SKELETON)
	save_run()
	return pos

# ------------------------------------------------------------------ the garden's seeds and plants

## A seed pod burst at `from` (SeedPod): its seed is flung from there to `pos` (SeedPod.shoved), and
## kept there as a dropped key (KeyRing.SEED) until taken. Without `from` it simply lies at `pos`.
func drop_seed (pos: Vector2, from: Vector2 = Vector2.INF) -> void:
	var id: int = record().drop_key(pos, KeyRing.SEED)
	_spawn_dropped_key.call_deferred(id, pos, KeyRing.SEED, from)
	save_run()

## Plant a carried seed at `plot` (Plot): it grows from here on (RunState.plants, RunState.reached).
func plant_seed (plot: Plot) -> void:
	if wizard() == null or run.plants.has(coord) or not player.keyring.spend_seed():
		return
	run.plants[coord] = {"furthest": 0, "door": false}
	RisoFx.burst(&"gain", plot.global_position, Vector2.ZERO, [Plate.ACCENT, Plate.BLUE])
	save_run()

## Pick the plant grown at `plot` (Plot): its reward, by how far the wizard went (Plot.tier): a star
## cluster, a skeleton key, or a hyperspace door that stands there for the rest of the run (paid for:
## free to go through), or a skeleton key where the level has a hyperspace door already. The plot is
## bare again but for a door.
func pick_plant (plot: Plot) -> void:
	var tier: int = plot.tier()
	if tier <= 0:
		return
	var pos: Vector2 = plot.global_position
	var hyper: int = Worlds.kind_of(Hyperspace)
	if tier >= 3 and not here.doors.has(hyper) and not Worlds.is_side(coord):
		run.plants[coord] = {"furthest": 0, "door": true}
		here.pay(Worlds.door(hyper), record())
		_spawn_plant_door()
	else:
		run.plants.erase(coord)
		if tier >= 2:
			var id: int = record().drop_key(pos, KeyRing.SKELETON)
			_spawn_dropped_key(id, pos, KeyRing.SKELETON)
		else:
			var cluster: Coin = Placeables.scene(LevelGen.Type.CLUSTER).instantiate() as Coin
			cluster.value = Rules.cluster_value(here.depth)
			map_elements.add_child(cluster)
			cluster.global_position = pos + Vector2(0, -40)
	RisoFx.burst(&"gain", pos, Vector2.ZERO, [Plate.ACCENT, Plate.PINK])
	save_run()

## The cell of this place's plot, if a plant here grew a hyperspace door (pick_plant), else null.
func plant_door_cell () -> Variant:
	if world == null or not bool((run.plants.get(coord, {}) as Dictionary).get("door", false)):
		return null
	var plots: Array[Vector2i] = world.objects_of(LevelGen.Type.PLOT)
	return plots[0] if not plots.is_empty() else null

## Small worms drawn to a plant grown big here (Wormlet.SWARM by its tier: a white flower, a great
## bloom): in free cells within Wormlet.SWARM_REACH cells of its plot (they live in the rock, and come
## out wherever the wizard is), chosen by hashing the level
## seed (no draw), laid in with the level each visit until it is picked; those slain stay slain (the
## record keeps them by their cell, as any enemy).
func _spawn_swarm () -> void:
	var plant: Dictionary = run.plants.get(coord, {})
	if plant.is_empty() or bool(plant.get("door", false)):
		return
	var count: int = Wormlet.SWARM[Plot.tier_of(int(plant.get("furthest", 0)))]
	var plots: Array[Vector2i] = world.objects_of(LevelGen.Type.PLOT)
	if count <= 0 or plots.is_empty():
		return
	var plot: Vector2i = plots[0]
	var homes: Array[Vector2i] = world.empties_where(func(v: Vector2i) -> bool:
		var d: int = LevelGen.dist(v, plot)
		return world.type_at(v) == LevelGen.Type.EMPTY and d >= 2 and d <= Wormlet.SWARM_REACH)
	homes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return RisoDecor.h(world.seed_for_colors, a, Wormlet.SWARM_DEAL) < RisoDecor.h(world.seed_for_colors, b, Wormlet.SWARM_DEAL))
	for v: Vector2i in homes.slice(0, count):
		loader.place_cell(v, LevelGen.Cell.new(LevelGen.Type.WORMLET))

## The hyperspace door a plant grew here, standing on its plot (pick_plant).
func _spawn_plant_door () -> void:
	var at: Variant = plant_door_cell()
	if at == null:
		return
	var door: LevelGen.Cell = LevelGen.Cell.new(LevelGen.Type.EXIT)
	door.extra_info = Worlds.door(Worlds.kind_of(Hyperspace))
	loader.place_cell(at, door)

func _spawn_dropped_key (id: int, pos: Vector2, color: int, from: Vector2 = Vector2.INF) -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var key: Node2D = Placeables.scene(LevelGen.Type.KEY).instantiate()
	key.set_meta(&"key_color", color)
	key.set_meta(&"dropped_id", id)
	key.position = pos
	map_elements.add_child(key)
	if from.is_finite() and from != pos:
		# Flung there from `from` (a burst seed pod's seed, SeedPod.shoved), in a low arc.
		key.position = from
		var fling: Callable = func(k: float) -> void:
			key.position = from.lerp(pos, k) + Vector2(0.0, -SeedPod.SHOVE_ARC * 4.0 * k * (1.0 - k))
		key.create_tween().tween_method(fling, 0.0, 1.0, SeedPod.SHOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## A bell of chasm `id` was rung (at cell `from`): its bridge lays itself from that side, and stays
## up for good.
func ring_bell (id: int, from: Vector2i = Vector2i(-1, -1)) -> void:
	var rec: LevelRecord = record()
	if rec.bridges.has(id):
		return
	rec.bridges[id] = true
	if map_elements != null and is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			var bridge: Bridge = node as Bridge
			if bridge != null and bridge.chasm == id:
				bridge.raise(from)
	save_run()

func bridge_up (id: int) -> bool:
	return record().bridges.has(id)

## The vane at `cell`, pointing `way` (+1 right, -1 left), was switched: on, the level's wind turns
## its way, and it is the next step entered into the level's temple's lock (Temple.step); off, the
## wind its way is a vane weaker (Rules.wind_of). Kept in the level record.
func switch_vane (cell: Vector2i, way: int) -> void:
	var rec: LevelRecord = record()
	if rec.vanes_on.has(cell):
		rec.vanes_on.erase(cell)
	else:
		rec.vanes_on[cell] = way
		rec.wind_way = way
		if world != null and not rec.temple_open:
			for t: Dictionary in world.temples:
				rec.temple_progress = Temple.step(world.get_cell(t["altar"]).extra_info, rec.temple_progress, way)
	save_run()

## Whether the vane at `cell` is switched on.
func vane_on (cell: Vector2i) -> bool:
	return record().vanes_on.has(cell)

## The level's wind (sky levels; Rules.wind_of): its way times its strength, 0 while still. It
## blows in gusts (gust_wind).
func level_wind () -> int:
	return Rules.wind_of(record())

## Seconds of game time in this place, for its gusts (counted in physics steps, from arriving).
var gust_clock: float = 0.0
## The light gates of the level being played (LightGate), by cell: whether each is up now.
var light_gates: Dictionary = {}

## Whether a gust is blowing now: Wind.STILL seconds of stillness, then a gust as long as the level's
## wind's strength makes it (Wind.gust_for), over again.
func gusting () -> bool:
	return fposmod(gust_clock, Wind.STILL + gust_length()) >= Wind.STILL

## How long (seconds) a gust blows here: Wind.gust_for the level's wind's strength.
func gust_length () -> float:
	return Wind.gust_for(absi(level_wind()))

## How near the next gust is (0 until Wind.WARN seconds before it, rising to 1 as it comes; 1 in it),
## for the art.
func gust_coming () -> float:
	var into: float = fposmod(gust_clock, Wind.STILL + gust_length())
	if into >= Wind.STILL:
		return 1.0
	return clampf((into - (Wind.STILL - Wind.WARN)) / Wind.WARN, 0.0, 1.0)

## The level's wind as it blows now: level_wind in a gust, 0 between.
func gust_wind () -> int:
	return level_wind() if gusting() else 0

## How fast a gust carries the wizard sideways (px/s, signed) at `pos` in a sky level, off the
## ground (Wind.carry_for its strength, as over a gap); none between gusts, and none where rock
## shelters them: within Wind.LEE cells upwind on their row or the row over it.
func gust_at (pos: Vector2) -> float:
	if world == null or here == null or not here.open():
		return 0.0
	var wind: int = gust_wind()
	if wind == 0 or sheltered(pos, signi(wind)):
		return 0.0
	return float(signi(wind)) * Wind.carry_for(absi(wind))

## Whether rock shelters `pos` from a wind blowing `way` (+1 right): rock within Wind.LEE cells
## upwind on its row or the row over it.
func sheltered (pos: Vector2, way: int) -> bool:
	var at: Vector2i = cell_at(pos)
	for row: int in [0, -1]:
		for k: int in range(1, Wind.LEE + 1):
			var up: Vector2i = at + Vector2i(-way * k, row)
			if world.is_valid(up) and world.is_ground(up):
				return true
	return false

## Boss `boss` died at `pos` (Bosses): slain for the rest of the run, so every gate level of its band
## opens; where it fell, a relic unlock waits (KeyRing.UNLOCK, kept as a dropped key until picked
## up), or, with every relic's move known (Bosses.relic_for finds none), a skeleton key and a star
## cluster; and beside that, its trophy (Trophy, trophy_spot).
func boss_slain (boss: StringName, pos: Vector2) -> void:
	if boss == &"" or run.bosses.has(boss):
		return
	run.bosses[boss] = true
	run.boss_trophies[boss] = [coord, trophy_spot(pos)]
	_spawn_boss_trophies()
	# The beast's souls go with it.
	if boss == &"beast":
		BeastSouls.end(run)
	if Bosses.relic_for(boss, run.run_seed, player) != &"":
		var unlock: int = record().drop_key(pos, KeyRing.UNLOCK)
		_spawn_dropped_key(unlock, pos, KeyRing.UNLOCK)
		save_run()
	else:
		var id: int = record().drop_key(pos, KeyRing.SKELETON)
		_spawn_dropped_key(id, pos, KeyRing.SKELETON)
		var cluster: Coin = Placeables.scene(LevelGen.Type.CLUSTER).instantiate() as Coin
		cluster.value = Rules.cluster_value(here.depth)
		map_elements.add_child(cluster)
		cluster.global_position = pos + Vector2(60, -40)
	RisoFx.burst(&"gain", pos, Vector2.ZERO, [Plate.ACCENT, Plate.PINK])
	save_run()

## The whale (Whale), if it is in this place now (WhaleHunt.here) and not just slain (its heart
## burst, the wizard spat out here: whale_burst).
func _spawn_whale () -> void:
	if not WhaleHunt.here(run, coord) or map_elements == null or _slay_on_arrival == &"whale":
		return
	var whale: Whale = (load("res://prefabs/whale.tscn") as PackedScene).instantiate() as Whale
	map_elements.add_child(whale)
	whale.setup(self)

## The eldritch beast woke in its chamber (Beast): its souls go out across the run, if they have
## not yet (BeastSouls.send).
func beast_woke () -> void:
	BeastSouls.send(run, coord)
	save_run()

## The beast's soul in this place was destroyed (BeastSoul): gone for the rest of the run.
func soul_destroyed () -> void:
	BeastSouls.destroyed(run, coord)
	RisoFx.burst(&"gain", player.global_position if wizard() != null else Vector2.ZERO, Vector2.ZERO, [Plate.PINK, Plate.NIGHT])
	save_run()

## The beast's soul, if one lies in this place (BeastSouls.here), on its floor (BeastSouls.spot),
## with abominations laid round it (BeastSouls.guard_spots), each time the place is entered. None of
## them is part of the level or its record.
func _spawn_souls () -> void:
	if map_elements == null or world == null or not BeastSouls.here(run, coord):
		return
	var at: Vector2i = BeastSouls.spot(run, coord, world)
	if at == BeastSouls.NO_SPOT:
		return
	var soul: BeastSoul = (load("res://prefabs/beast_soul.tscn") as PackedScene).instantiate() as BeastSoul
	map_elements.add_child(soul)
	soul.position = cell_position(at)
	soul.setup(self, at)
	for v: Vector2i in BeastSouls.guard_spots(world, at):
		var thing: Node2D = Placeables.scene(LevelGen.Type.ABOMINATION).instantiate() as Node2D
		LevelLoader.arm(thing, here.depth)
		(thing.get_node("Wound") as Wound).stars = false
		map_elements.add_child(thing)
		thing.position = cell_position(v)

## The whale's mouth shut on the wizard (hidden in it, Whale._gulp): into its belly (Belly), at its
## way back, seen again once the way there has covered the screen.
func enter_belly () -> void:
	if travelling or run_ending > 0.0:
		return
	var to: Vector2i = Worlds.side_at(Worlds.kind_of(Belly), coord)
	await _pass(Vector2.RIGHT, to)
	if wizard() != null:
		player.visible = true
	_arrive(to, Exit.BACK)

## The boss to slay as the wizard arrives where it fell (its relic is left there): the whale, whose
## heart bursts in its belly while its relic waits in its level, by the way on.
var _slay_on_arrival: StringName = &""

## The whale's heart burst (WhaleHeart): it is slain, and the wizard is spat out of its belly into
## its level, at the way on, the whale's relic beside it.
func whale_burst () -> void:
	if travelling or not Worlds.is_side(coord):
		return
	var to: Vector2i = Worlds.origin_of(coord)
	_slay_on_arrival = &"whale"
	await _pass(Vector2.LEFT, to)
	_arrive(to, Exit.DEEPER)

## Debug runs (the F7 panel's Full heal): the wizard back to full health at once. False when not a
## debug run, or there is no wizard.
func full_heal () -> bool:
	var who: Player = wizard()
	if not debug or who == null:
		return false
	who.health.health = who.health.max_health
	return true

## Debug runs (the F7 panel): slay this place's boss at once. One here in person (the worm, the
## bramble, the golem, the necromancer, the beast, or the whale's heart) dies as by any blow, leaving its
## relic; else the boss whose gate this is, if it lives (it has no place to stand here), is slain
## where the wizard stands.
## False if there is none to slay.
func slay_boss () -> bool:
	if map_elements != null and is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if node.is_queued_for_deletion():
				continue
			if node is Worm and not (node as Worm).slain:
				(node as Worm).slay()
				return true
			if node is Bramble and not (node as Bramble).slain:
				(node as Bramble).slay()
				return true
			if node is Golem and not (node as Golem).slain:
				(node as Golem).slay()
				return true
			if node is Necromancer and not (node as Necromancer).slain:
				(node as Necromancer).slay()
				return true
			if node is Beast and not (node as Beast).slain:
				(node as Beast).slay()
				return true
			if node is WhaleHeart:
				(node as WhaleHeart).slay()
				return true
			if node is Whale:
				# Its relic waits by the way on, as when its heart bursts (whale_burst).
				var on: Vector2 = cell_position(world.exits[Exit.DEEPER]) if world.exits.has(Exit.DEEPER) else player.global_position
				boss_slain(&"whale", on)
				node.queue_free()
				return true
	var gate: StringName = here.gate if here != null else &""
	if gate != &"" and not run.bosses.has(gate) and player != null:
		boss_slain(gate, player.global_position)
		return true
	return false

## Where a boss's trophy drops, its boss fallen at `pos`: a cell to one side of it (the relic's
## spot), the nearest open one, at the same height in its cell; else just over it.
func trophy_spot (pos: Vector2) -> Vector2:
	var at: Vector2i = cell_at(pos)
	var within: Vector2 = pos - cell_position(at)
	for dx: int in TROPHY_SIDES:
		var c: Vector2i = at + Vector2i(dx, 0)
		if world != null and world.is_valid(c) and not world.is_ground(c):
			return cell_position(c) + within
	return pos + TROPHY_OVER


## The trophies slain bosses left in this place, where they fell, until picked up.
func _spawn_boss_trophies () -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	for boss: StringName in run.boss_trophies:
		var entry: Array = run.boss_trophies[boss]
		if entry[0] != coord or map_elements.get_children().any(func(n: Node) -> bool: return n is Trophy and (n as Trophy).boss == boss):
			continue
		var trophy: Trophy = Prefabs.make(TROPHY) as Trophy
		trophy.setup(self, boss)
		map_elements.add_child(trophy)
		trophy.global_position = entry[1]


## The wizard picked up boss `boss`'s trophy at `pos`: theirs to carry for the rest of the run.
func trophy_taken (boss: StringName, pos: Vector2) -> void:
	run.boss_trophies.erase(boss)
	run.trophies[boss] = Trophy.CARRIED
	RisoFx.burst(&"gain", pos, Vector2.ZERO, [Plate.ACCENT, Plate.EYE])
	Wound.shake(8.0, 0.2)
	save_run()


## The wizard set boss `boss`'s trophy on its stand at `pos` (TrophyStand); with every boss's set,
## the run is won.
func set_trophy (boss: StringName, pos: Vector2) -> void:
	run.trophies[boss] = Trophy.SET
	RisoFx.burst(&"gain", pos + Vector2(0, -80), Vector2.ZERO, [Plate.ACCENT, Plate.GLOW])
	save_run()
	if run.trophies_all_set():
		win_run()


## The relics slain bosses left in this place, where they fell, until taken.
func _spawn_boss_relics () -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	for boss: StringName in run.boss_relics:
		var entry: Array = run.boss_relics[boss]
		if entry[0] != coord or map_elements.get_children().any(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == boss):
			continue
		var relic: Relic = Placeables.scene(LevelGen.Type.RELIC).instantiate() as Relic
		relic.set_meta(&"boss", boss)
		map_elements.add_child(relic)
		relic.global_position = entry[1]
		relic.setup(self, Vector2i.ZERO, entry[2])

## Whether the switch at `cell` here is on (Switch: as last turned, else as it started).
func switch_on (cell: Vector2i) -> bool:
	return world != null and Switch.is_on_in(world, record(), cell)

## Turn the switch at `cell` here on or off: the record keeps it.
func set_switch (cell: Vector2i, on: bool) -> void:
	record().switched[cell] = on
	save_run()

## Whether the switch gate at `gate` here is up: its switch on, or for a station gate (its extra
## info the station's number), its station on.
func gate_open (gate: Vector2i) -> bool:
	var lever: Variant = world.get_cell(gate).extra_info if world != null and world.is_valid(gate) else null
	if lever is int:
		return station_on(lever)
	return lever is Vector2i and switch_on(lever)

## The crags' tower puzzle (Stations, TowerSwitch). The tower flipped last here, locked until another
## is flipped; -1 for none. Not kept: the level loading again lifts the lock (so a wizard stranded by
## a flip can leave, or die, and flip it back).
var last_tower: int = -1

## Whether gondola station `i` here is on (LevelRecord.stations).
func station_on (i: int) -> bool:
	var rec: LevelRecord = record()
	return rec.stations >= 0 and rec.stations & (1 << i) != 0

## On the first visit to a level with a gondola, only the station nearest the way the wizard came in
## is on (LevelRecord.stations).
func _deal_stations () -> void:
	var rec: LevelRecord = record()
	if rec.stations >= 0 or world == null or world.circuit.is_empty():
		return
	var gates: Array[Vector2i] = world.circuit["gates"]
	var came: Vector2i = world.exits.get(arrival, world.exits.get(Exit.BACK, Vector2i.ZERO)) if arrival >= 0 else world.exits.get(Exit.BACK, Vector2i.ZERO)
	var nearest: int = 0
	for i: int in range(gates.size()):
		if LevelGen.dist(gates[i], came) < LevelGen.dist(gates[nearest], came):
			nearest = i
	rec.stations = 1 << nearest

## Flip tower `tower`'s switch, turning over the stations in `mask`, unless it is the tower flipped
## last (locked). Each station gate here goes up or down with its station. Returns whether it flipped.
func flip_tower (tower: int, mask: int) -> bool:
	if tower == last_tower or world == null:
		return false
	var rec: LevelRecord = record()
	rec.stations = maxi(rec.stations, 0) ^ mask
	last_tower = tower
	if is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if node is SwitchGate and (node as SwitchGate).station >= 0:
				(node as SwitchGate).set_up(station_on((node as SwitchGate).station))
	save_run()
	return true

## Whether tower `tower` here is cold (CragsArchetype.set_stations) and not yet woken by an empowered
## strike on its spire (LevelRecord.woken): its switch does nothing.
func tower_cold (tower: int) -> bool:
	if world == null or tower < 0 or tower >= world.towers.size():
		return false
	return bool(world.towers[tower].get("cold", false)) and not record().woken.has(tower)

## An empowered strike on tower `tower`'s spire (Spire): a cold tower wakes for good; any other
## flips its switch, under the same lock as by hand (flip_tower). Whether anything came of it.
func strike_spire (tower: int) -> bool:
	if world == null or tower < 0 or tower >= world.towers.size():
		return false
	if tower_cold(tower):
		record().woken[tower] = true
		save_run()
		return true
	var at: Vector2i = world.towers[tower].get("switch", Vector2i(-1, -1))
	if not world.is_valid(at) or world.type_at(at) != LevelGen.Type.TOWER_SWITCH:
		return false
	return flip_tower(tower, int((world.get_cell(at).extra_info as Dictionary).get("mask", 0)))

## The lodestone here was touched (Lodestone): `spell` is tempered for the rest of the run (Empower)
## and, the stone new, what is left of empowerment's recharge is cut to the new one. Whether it was new.
func touch_lodestone (spell: StringName) -> bool:
	if not run.touch_lodestone(coord, spell):
		return false
	var empower: Empower = Empower.of(wizard())
	if empower != null:
		empower.shorten()
	seen_version += 1
	save_run()
	return true

## The gondola brought all the way to its top station (Gondola): every level this one's exits lead
## to (side worlds aside) has its map inked whole, as its own ink well would (ink_place), so a
## lodestone there shows on the worlds map.
func ink_neighbours () -> void:
	for at: Vector2i in here.neighbours():
		if not Worlds.is_side(at):
			ink_place(at)
	seen_version += 1
	save_run()

## Ink the whole map of the place at `at` (not the one being played): its record is mapped, and every
## cell seen, now if its layout is known, else when it is (LevelRecord.seen_for).
func ink_place (at: Vector2i) -> void:
	var rec: LevelRecord = run.record(at)
	rec.mapped = true
	var w: LevelGen = loader.laid_out(at) if loader != null else null
	if w != null:
		rec.seen_for(w.size.x * w.size.y).fill(1)
	else:
		rec.seen = PackedByteArray()

## The chain on the bell at `cell` is off (by its key): for good.
func free_bell (cell: Vector2i) -> void:
	record().bells_free[cell] = true
	save_run()

func bell_free (cell: Vector2i) -> bool:
	return record().bells_free.has(cell)

## A cracked wall broken: gone for good. If something you stand at stood on it, a ledge takes
## its place (prop_up).
func mark_broken (node: Node) -> void:
	if node.has_meta(&"cell"):
		record().broken[node.get_meta(&"cell")] = true
		prop_up([node.get_meta(&"cell")])
		save_run()

## Things you stand at to use them (Placeables, "stander": an exit, the shrine across both its
## cells, a lantern, the ink well, a relic, a bell, a switch, a teleporter...) always keep something
## under them: where rock under one is broken (a cracked wall, a secret room's rock), a ledge (a
## platform) appears in its place, at once, or as the level loads for rock broken before.
## Cells given a ledge in the level as loaded now.
var _props: Dictionary = {}

## Whether broken cell `c` held up something you stand at.
func holds_up_stander (c: Vector2i) -> bool:
	if world == null:
		return false
	var above: Vector2i = c + Vector2i.UP
	if not world.is_valid(above):
		return false
	if Placeables.has_flag(world.type_at(above), &"stander"):
		return true
	# The shrine stands across two cells: its own and the one to its right.
	var left: Vector2i = above + Vector2i.LEFT
	return world.is_valid(left) and world.type_at(left) == LevelGen.Type.SHRINE

## A ledge in each of `cells` (broken rock) that held up something you stand at.
func prop_up (cells: Array) -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	for c: Vector2i in cells:
		if _props.has(c) or not holds_up_stander(c):
			continue
		_props[c] = true
		var ledge: Node2D = Placeables.scene(LevelGen.Type.PLATFORM).instantiate()
		ledge.set_meta(&"cell", c)
		ledge.set_meta(&"prop", true)
		map_elements.add_child(ledge)
		ledge.position = cell_position(c)

# ------------------------------------------------------------------ secret rooms and relics

## The secret room (its number in LevelGen.secrets) whose unopened rock is at cell `v`, or -1.
func secret_at (v: Vector2i) -> int:
	if world == null or not world.is_valid(v):
		return -1
	var cell: LevelGen.Cell = world.get_cell(v)
	if cell.type != LevelGen.Type.CRACKED or cell.extra_info == null:
		return -1
	var id: int = int(cell.extra_info)
	return -1 if record().secrets.has(id) else id

## Open secret room `id` for good: its rock (and entrance) crumbles, kept broken in the record,
## and its rewards appear.
func open_secret (id: int) -> void:
	if world == null or id < 0 or id >= world.secrets.size():
		return
	var rec: LevelRecord = record()
	if rec.secrets.has(id):
		return
	rec.secrets[id] = true
	var secret: Dictionary = world.secrets[id]
	var middle: Vector2 = Vector2.ZERO
	for c: Vector2i in secret["room"] + secret["entrance"]:
		rec.broken[c] = true
		middle += cell_position(c) / float(secret["room"].size() + secret["entrance"].size())
	if map_elements != null and is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if int(node.get_meta(&"secret", -1)) == id:
				node.queue_free()
	_spawn_secret_rewards(id)
	prop_up(secret["room"] + secret["entrance"])
	RisoFx.burst(&"gain", middle, Vector2.ZERO, [Plate.ACCENT, Plate.BLUE])
	RisoFx.burst(&"hit", middle, Vector2.UP, [Plate.BLUE, Plate.NIGHT])
	Wound.shake(14.0, 0.3)
	# Reprint the rock without the room.
	if RisoPrint.instance != null:
		RisoPrint.instance.world_built(self, coord.y)
	seen_version += 1
	save_run()

func _spawn_secret_rewards (id: int) -> void:
	if world == null or id < 0 or id >= world.secrets.size():
		return
	for reward: Array in world.secrets[id]["rewards"]:
		var cell: LevelGen.Cell = LevelGen.Cell.new(reward[1])
		cell.extra_info = reward[2]
		loader.place_cell(reward[0], cell)

## A relic was taken in this level.
func relic_taken () -> void:
	run.relic_taken(coord)
	save_run()

## Whether the level's relic is still carried by its master (Scholar.relic): not taken, nor left
## lying.
func relic_carried () -> bool:
	if run.relics_found.has(coord):
		return false
	var left: Dictionary = record().relics_left
	return not left.keys().any(func(id: int) -> bool: return bool(left[id][2]))

## A beaten master left relic `move` lying at `pos`, free (the fight was its price): the level's own
## when `own` (a master out in the level carried it), else an instructor's. Kept in the record until
## taken (LevelRecord.relics_left).
func relic_left (pos: Vector2, move: StringName, own: bool) -> void:
	var rec: LevelRecord = record()
	var id: int = rec.next_drop
	rec.next_drop = id + 1
	rec.relics_left[id] = [pos, move, own]
	_spawn_left_relics.call_deferred()
	RisoFx.burst(&"gain", pos, Vector2.ZERO, [Plate.ACCENT, Plate.PINK])
	save_run()

## A relic left lying (relic_left) taken: gone from the record; the level's own counts as its relic
## found (relic_taken).
func left_relic_taken (id: int) -> void:
	var rec: LevelRecord = record()
	if rec.relics_left.has(id) and bool(rec.relics_left[id][2]):
		run.relic_taken(coord)
	rec.relics_left.erase(id)
	save_run()

## Every relic left lying here (relic_left) not yet standing.
func _spawn_left_relics () -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var rec: LevelRecord = record()
	for id: int in rec.relics_left:
		if map_elements.get_children().any(func(n: Node) -> bool: return int(n.get_meta(&"left", -1)) == id):
			continue
		var relic: Relic = Placeables.scene(LevelGen.Type.RELIC).instantiate() as Relic
		relic.set_meta(&"left", id)
		map_elements.add_child(relic)
		relic.global_position = rec.relics_left[id][0]
		relic.setup(self, Vector2i.ZERO, rec.relics_left[id][1])

## The relic a shrine would point to: the nearest one neither found nor already marked, or null.
func next_relic () -> Variant:
	return run.next_relic(coord)

## A shrine's hint of boss `boss`: which way its column lies from this one (-1 left, 1 right, 0
## this one; Bosses.column), noted for the worlds map (RunState.boss_hints). Returns the way.
func hint_boss (boss: StringName) -> int:
	var way: int = signi(Bosses.column(boss, run.run_seed) - coord.x)
	var hints: Array = run.boss_hints.get(boss, [])
	hints.append([coord.x, way])
	run.boss_hints[boss] = hints
	save_run()
	return way

## A shrine's door: dig this level's way on where the labyrinth left it out (RunState.dug), and put
## its door in at the spot kept for it; the level it leads into gets its way back as well.
func dig_way_on () -> void:
	var into: Vector2i = coord + Vector2i(0, NextWorldDef.away(coord.y))
	run.dug[into] = true
	NextWorldDef.dug = run.dug
	_spawn_dug_doors([Exit.DEEPER])
	seen_version += 1
	save_run()

## The doors of the ways dug into this level since it was laid out (NextWorldDef.dug_ways), or of
## `only` those of them: each at the spot kept for it.
func _spawn_dug_doors (only: Array = []) -> void:
	for exit: int in here.dug_ways():
		if not only.is_empty() and not only.has(exit):
			continue
		if not world.exits.has(exit):
			continue
		var door: LevelGen.Cell = LevelGen.Cell.new(LevelGen.Type.EXIT)
		door.extra_info = exit
		loader.place_cell(world.exits[exit], door)

## A shrine's hint: mark that relic on the worlds map. Returns its level, or null.
func hint_relic () -> Variant:
	var at: Variant = run.hint_relic(coord)
	if at != null:
		save_run()
	return at

# ------------------------------------------------------------------ moving between places

## Begin a run at depth 0 of `run_seed`; its start lantern is lit. With a `row`, the run begins on
## that row of the same world instead (the generation lab, tools/gen_lab, playing a level it made).
## With `tutorial`, it begins in the tutorial (Tutorial), by its lantern, lit, and comes out into
## depth 0 through the tutorial's way out.
func start_run (seed_value: int, row: int = 0, tutorial: bool = false) -> void:
	run.start(seed_value)
	# What the map knew of this world in runs before (Known).
	Known.teach(run)
	coord = Vector2i(seed_value, row)
	# At the start, its own place for a run's first steps; elsewhere (the generation lab), its way back.
	arrival = -1 if row == 0 else Exit.BACK
	# With the tutorial, the run begins in it (Tutorial), and comes out by the start's door into it.
	if tutorial and row == 0:
		coord = Tutorial.of(seed_value)
		ControlHint.learned.clear()
	if wizard() != null:
		Abilities.reset(player)
		if debug:
			player.collect(DEBUG_STARS - player.coins.coins)
	_clear_ghost()
	_load_level()

## Leave through `exit` and arrive where the place's definition says it leads (NextWorldDef.lead).
## The exits taken are kept in the record (`ways_taken`), so the worlds map can join the places.
func travel (exit: int) -> void:
	if travelling:
		return
	var lead: Dictionary = here.lead(exit)
	if lead.is_empty():
		return
	record().ways_taken[exit] = true
	if Worlds.kind_at(coord) == Tutorial.kind_number():
		Tutorial.mark_done()
	var next: Vector2i = lead["to"]
	await _pass(lead["way"], next)
	_arrive(next, lead["arrive"])

## Step through a tier III rift into level `to`, coming out at `at` (its end of the link).
func rift_travel (to: Vector2i, at: Vector2) -> void:
	if travelling or run_ending > 0.0:
		return
	var d: Vector2i = to - coord
	var way: Vector2 = Vector2(signf(d.x), signf(d.y)) if d != Vector2i.ZERO else Vector2.DOWN
	if absi(d.x) > 0 and absi(d.y) > 0:
		way = Vector2(0, signf(d.y))
	await _pass(way, to)
	arrival_pos = at
	_arrive(to, -3)

## Arriving by balloon (Balloon): by the balloon moored in the place arrived at (else its way back).
const ARRIVE_BALLOON: int = -4

## Ride a balloon (Balloon) along the row to level `to`, coming down by the balloon moored there.
func balloon_travel (to: Vector2i) -> void:
	if travelling or run_ending > 0.0:
		return
	await _pass(Vector2(signf(float(to.x - coord.x)), 0.0), to)
	_arrive(to, ARRIVE_BALLOON)

## Debug runs (the F7 panel's Travel rows): go straight to place `to`, a level or a side world,
## arriving at its way back. Nothing is paid or opened on the way.
func debug_travel (to: Vector2i) -> void:
	if not debug or travelling or run_ending > 0.0 or not Worlds.valid(to):
		return
	await _pass(Vector2.DOWN, to)
	_arrive(to, Exit.BACK)

## Arriving by the place's boss (debug_to_boss): see _beside_boss.
const ARRIVE_BOSS: int = -6
## How many cells from the boss a jump to it sets the wizard down, at the least.
const BOSS_BESIDE: int = 4

## Debug runs (the F7 panel's boss row): go straight to boss `name`, alive or slain: its gate level
## in the column it is met in this run (Bosses.column), arriving beside it (ARRIVE_BOSS), or for the
## whale, its belly in world `column`, by its heart.
## Nothing is paid or opened on the way.
func debug_to_boss (name: StringName, column: int) -> void:
	if not debug or travelling or run_ending > 0.0:
		return
	if name == &"whale":
		var belly: Vector2i = Worlds.side_at(Worlds.kind_of(Belly), Vector2i(column, WhaleHunt.row()))
		await _pass(Vector2.DOWN, belly)
		_arrive(belly, Exit.BACK)
		return
	var row: int = Bosses.row_of(name)
	if row == 0:
		return
	var to: Vector2i = Vector2i(Bosses.column(name, run.run_seed), row)
	await _pass(Vector2.DOWN, to)
	_arrive(to, ARRIVE_BOSS)

## Where a jump to the place's boss sets the wizard down (ARRIVE_BOSS): the free floor nearest its
## cell, at least BOSS_BESIDE cells off, in the open it stands in; `fallback` (its way back) with no
## boss here or no such floor.
func _beside_boss (fallback: Vector2i) -> Vector2i:
	var bosses: Array[Vector2i] = world.objects_of(LevelGen.Type.BOSS)
	if bosses.is_empty():
		return fallback
	var boss: Vector2i = bosses[0]
	var room: Dictionary = world.reach_from(boss)
	var spot: Variant = LevelGen.best_of(world.free_floors(), func(v: Vector2i) -> int: return LevelGen.dist(v, boss),
			func(v: Vector2i) -> bool: return room.has(v) and LevelGen.dist(v, boss) >= BOSS_BESIDE)
	if spot == null:
		return fallback
	var at: Vector2i = spot
	return at

## The F7 panel's Difficulty row: lay this place out again under the preset now picked (it holds
## more or fewer foes), arriving at its way back. What the run has noted of the place (things taken
## or slain) was noted of the old layout, so it may not all line up.
func lay_out_again () -> void:
	if travelling or run_ending > 0.0:
		return
	await _pass(Vector2.DOWN, coord)
	_arrive(coord, Exit.BACK)

func respawn_in_other_level () -> void:
	await _pass(Vector2.UP, run.respawn_coord)
	jump_to(run.respawn_coord, -2)

## Load place `to`, arriving at `how` (an exit there, or -3 for arrival_pos). Coming into a sky
## level, the whale moves (WhaleHunt.move).
func _arrive (to: Vector2i, how: int) -> void:
	run.reached(to)
	WhaleHunt.move(run, to)
	jump_to(to, how)

## Go straight to place `at`, arriving at `how`: an exit there (its way back by default), -1 for a
## run's start, -2 for the respawn lantern, -3 for arrival_pos, or one of the ARRIVE_ kinds. No
## transition is swept over the view and nothing is paid, opened or noted on the way (not even that
## the place was reached): the level is simply loaded, the wizard frozen until it is in the scene.
## Travel of every kind ends here; the tests call it to put the wizard somewhere (TestKit.go).
func jump_to (at: Vector2i, how: int = Exit.BACK) -> void:
	coord = at
	arrival = how
	_load_level()

## Freeze the wizard and sweep the printed transition over the view before a level changes.
func _pass (way: Vector2, next: Vector2i) -> void:
	travelling = true
	if wizard() != null:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	if RisoTransition.instance != null:
		await RisoTransition.instance.cover(way, next)

## Load the place at `coord` (see LevelLoader), freezing the wizard until it is in the scene.
func _load_level () -> void:
	travelling = true
	here = Rules.def_for(coord)
	if wizard() != null:
		player.set_physics_process(false)
		player.set_collision(false)
	loader.request(coord)

## The place's layout is ready: build it in the scene as its record leaves it.
func _level_ready (built: LevelGen) -> void:
	gust_clock = 0.0
	if world != null:
		loader.clear()
	world = built
	wizard()
	light_gates.clear()
	institute.level_begun()
	last_tower = -1
	_deal_stations()
	loader.build(world)
	_spawn_dug_doors()
	_spawn_plant_door()
	_spawn_swarm()
	var rec: LevelRecord = record()
	# What was seen of it in runs before, if it is laid out as it was then (Known).
	if not Worlds.is_side(coord):
		var known: PackedByteArray = Known.seen_for(coord, world)
		if not known.is_empty():
			rec.seen = Known.merged(rec.seen_for(world.size.x * world.size.y), known)
	# Secret rooms already opened: their rewards (the rest of the room stays broken, see
	# open_secret). After everything else, so the rest of the level lands where it always has.
	for id: int in rec.secrets:
		_spawn_secret_rewards(id)
	for id: int in rec.dropped:
		_spawn_dropped_key(id, rec.dropped[id][0], rec.dropped[id][1])
	Rift.restore(self)
	_spawn_boss_relics()
	_spawn_boss_trophies()
	_spawn_left_relics()
	_spawn_whale()
	_spawn_souls()
	_spawn_lessons()
	institute.level_ready()
	# Rock broken before, under things you stand at: their ledges.
	_props.clear()
	prop_up(rec.broken.keys())
	_spawn_ghost()
	_spawn_worm_sign()
	_arrived()

## The place is in the scene: lay its rock, put the wizard at the way in, and carry on.
func _arrived () -> void:
	loader.lay_terrain(world, here.open())
	_last_seen_cell = Vector2i(-9999, -9999)
	institute.arriving()
	if debug:
		# Debug runs see every level's whole map from the start (its ink well still works).
		_seen().fill(1)
	seen_version += 1
	# Arrive at the matching exit; a new run starts at its lit start lantern, a respawn at the lantern.
	var at: Vector2i = world.exits.get(Exit.BACK, Vector2i.ZERO)
	if arrival >= 0 and world.exits.has(arrival):
		at = world.exits[arrival]
		# The side door just come through stays open behind the player: the way back is free.
		if arrival == Exit.LEFT or arrival == Exit.RIGHT:
			record().lateral_open[arrival] = true
	elif arrival >= 0 and Worlds.door_kind(arrival) >= 0 and plant_door_cell() != null:
		# Back out of the hyperspace a plant's door led into: by that door, on its plot.
		at = plant_door_cell()
	if arrival == -1 and world.is_valid(world.start):
		at = world.start
		_set_respawn(coord, world.start_lantern if world.is_valid(world.start_lantern) else at)
	elif arrival == -1:
		_set_respawn(coord, world.exit_lanterns.get(Exit.BACK, at))
	elif arrival == -2:
		at = run.respawn_cell
		_set_respawn(coord, run.respawn_cell)
	elif arrival == ARRIVE_BALLOON and world.is_valid(world.balloon):
		at = world.balloon
	elif arrival == ARRIVE_BOSS:
		at = _beside_boss(at)
	elif arrival == InstitutePlay.ARRIVE_WAY_BACK and run.way_back.size() >= 4 and run.way_back[0] == coord and run.way_back[1] != Vector2.INF:
		at = cell_at(run.way_back[1])
	if player != null:
		player.position = arrival_pos if arrival == -3 else cell_position(at)
		player.velocity = Vector2.ZERO
		player.set_collision(true)
		player.set_physics_process(true)
		player.grace()
		institute.arrived(at if arrival != -3 else cell_at(arrival_pos))
		# A trip (through a portal, or a warp) cut short by a death or a run's end never got to show
		# the wizard again, and its portal is gone with the old level: end it here.
		if player.has_meta(&"portal_trip"):
			player.remove_meta(&"portal_trip")
		RisoPrint.portal_reveal(player)
	institute.settled()
	travelling = false
	if _slay_on_arrival != &"":
		var on: Vector2i = world.exits.get(Exit.DEEPER, at)
		boss_slain(_slay_on_arrival, cell_position(on) + Vector2(-140.0, 0.0))
		_slay_on_arrival = &""
	_refresh_lanterns()
	# What the run knows goes into the kept map here, once a level, not with every autosave (it
	# goes over every record of the run and writes the whole kept map).
	Known.note(run, coord, world, loader.laid_out)
	if RisoPrint.instance != null:
		RisoPrint.instance.world_built(self, coord.y)
	if RisoTransition.instance != null:
		RisoTransition.instance.reveal()
	save_run()
	# The new level wakes around the wizard (the camera catches up next frame).
	loader.wake_around(player.global_position if player != null else Vector2.INF)
	loader.prefetch_neighbours(here)

## Another place's layout, for the map: the place being played, or one laid out from its seed (on
## a worker, LevelLoader.world_at: null until it is, so ask again next frame).
func world_at (at: Vector2i) -> LevelGen:
	if at == coord and world != null:
		return world
	return loader.world_at(at)

# ------------------------------------------------------------------ the institute



## Studying, at `at` (a lit lantern, Checkpoint, which it burns out; the library's desk,
## study_at_desk): the oldest paper carried that teaches something (learn_paper) is learned. Returns
## whether one was.
func study (at: Vector2) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for code: int in player.keyring.papers():
		if learn_paper(code, at):
			return true
	return false

## Whether exam paper `code` would teach something learned now (learn_paper): a spell that takes a
## slot, not one held there already at that tier or higher.
func teaches_paper (code: int) -> bool:
	var a: StringName = KeyRing.paper_spell(code)
	if a == &"" or Abilities.slot_of(a) == &"" or player == null or not is_instance_valid(player):
		return false
	return not (Abilities.spell(player, Abilities.slot_of(a)) == a and Abilities.tier(player, a) >= KeyRing.paper_tier(code))

## How many lanterns the wizard has burned out this game, by studying or into mend (burn_lantern),
## so the tutorial's card for burning one knows when it has been done (ControlHint.BURN).
var lanterns_burned: int = 0

## Whether the lantern `lantern` would burn into the utility spell held if the wizard used it now:
## it is the lantern lit as where they come back to, and they hold mend with a draught or more drunk,
## or resurrect with a rite or more spent (burn_lantern). A lantern that can be burned shows a drop
## of pink light over it (LanternArt).
func can_burn (lantern: Node) -> bool:
	if travelling or run_ending > 0.0 or player == null or not is_instance_valid(player) or not is_respawn_lantern(lantern) or is_lantern_spent(lantern):
		return false
	var held: StringName = Abilities.spell(player, &"utility")
	if held == &"mend":
		var mend: Mend = player.get_node_or_null("Mend") as Mend
		return mend != null and mend.draughts() < mend.draughts_max()
	if held == &"resurrect":
		var rise: Resurrect = player.get_node_or_null("Resurrect") as Resurrect
		return rise != null and rise.rites() < rise.rites_max()
	return false

## Burn a lantern out, by studying at it (study) or to fill the utility spell held (can_burn), as a
## death does: it protects the wizard no more, and is not lit again this run
## (RunState.spend_lantern). A lantern is the only thing that fills mend's draughts and resurrect's
## rites once spent (besides learning a tier at a shrine): burning one fills the one held in the
## utility slot, whichever way it was burned.
func burn_lantern (lantern: Node) -> void:
	if not lantern.has_meta(&"cell"):
		return
	run.spend_lantern(coord, lantern.get_meta(&"cell"))
	if run.respawn_coord == coord and run.respawn_cell == lantern.get_meta(&"cell"):
		run.vulnerable = true
	refill_utility()
	lanterns_burned += 1
	RisoFx.burst(&"gain", (lantern as Node2D).global_position + Vector2(0, -60), Vector2.ZERO, [Plate.EYE, Plate.PINK])
	_refresh_lanterns()
	save_run()

## Fill the utility spell held, mend's draughts or resurrect's rites: by burning a lantern
## (burn_lantern), or mending at a shrine (Shrine.buy_mend).
func refill_utility () -> void:
	if player == null or not is_instance_valid(player):
		return
	var held: StringName = Abilities.spell(player, &"utility")
	var mend: Mend = player.get_node_or_null("Mend") as Mend
	var rise: Resurrect = player.get_node_or_null("Resurrect") as Resurrect
	if held == &"mend" and mend != null:
		mend.refill()
	elif held == &"resurrect" and rise != null:
		rise.refill()

## The paper the library's desk (StudyDesk) would teach now, or 0: in class time, to a wizard in the
## library who has not studied there this period (LevelRecord.studied), the oldest carried that
## teaches something (teaches_paper). Free: the price is the bell that began class time.
func desk_paper () -> int:
	if not institute.timetabled() or player == null or not is_instance_valid(player):
		return 0
	var rec: LevelRecord = record()
	if rec.passing or rec.studied == rec.rings:
		return 0
	var hall: int = Timetable.hall_inside(world, cell_at(player.global_position))
	if hall < 0 or world.halls[hall]["kind"] != &"library":
		return 0
	for code: int in player.keyring.papers():
		if teaches_paper(code):
			return code
	return 0

## Study at the library's desk, at `at` (desk_paper): its paper learned, once this period. Returns
## whether one was.
func study_at_desk (at: Vector2) -> bool:
	var code: int = desk_paper()
	if code == 0 or not learn_paper(code, at):
		return false
	record().studied = record().rings
	save_run()
	return true

## Exam paper `code` learned, at `at`: its spell takes its slot at the paper's tier, and the spell it
## puts out of the slot comes back as a paper (put_back). A paper of the spell already held, at a tier
## no higher than it is known, teaches nothing (and stays on the ring). Returns whether it taught.
func learn_paper (code: int, at: Vector2) -> bool:
	if not teaches_paper(code):
		return false
	var a: StringName = KeyRing.paper_spell(code)
	var tier: int = KeyRing.paper_tier(code)
	var held: StringName = Abilities.spell(player, Abilities.slot_of(a))
	var held_tier: int = Abilities.tier(player, held) if held != &"" else 0
	player.keyring.spend(code)
	Abilities.set_tier(player, a, tier)
	if held != &"" and held != a:
		put_back(held, held_tier, at)
	RisoFx.burst(&"gain", at, Vector2.ZERO, [Plate.ACCENT, Plate.GLOW])
	Wound.shake(6.0, 0.15)
	save_run()
	return true

## Spell `a`, known at `tier`, put out of its slot (a lantern's study, a shrine's boon, a lesson): it
## comes back as an exam paper (KeyRing.paper), onto the key ring (one put off a full ring is left
## lying at `at`).
func put_back (a: StringName, tier: int, at: Vector2) -> void:
	if a != &"" and tier > 0:
		institute.give_paper(KeyRing.paper(a, tier), at)

## A master fell at `pos`, having mastered `ability`: its lesson (Lesson) waits where it fell, once
## a master (the one at `cell`): beaten again after a death, it leaves nothing more.
func leave_lesson (cell: Vector2i, pos: Vector2, ability: StringName) -> void:
	var rec: LevelRecord = record()
	if ability == &"" or rec.lessons.has(cell):
		return
	rec.lessons[cell] = {"at": pos, "ability": ability, "taken": false, "left": []}
	_spawn_lesson(cell)
	save_run()

## Every lesson here with something still on it.
func _spawn_lessons () -> void:
	for cell: Vector2i in record().lessons:
		_spawn_lesson(cell)

## A lesson's prefab (loaded when first needed, not preloaded: it would load in a circle).
const LESSON: String = "res://prefabs/lesson.tscn"

func _spawn_lesson (cell: Vector2i) -> void:
	var e: Dictionary = record().lessons.get(cell, {})
	if e.is_empty() or (bool(e.get("taken", false)) and (e.get("left", []) as Array).is_empty()):
		return
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var lesson: Lesson = (load(LESSON) as PackedScene).instantiate() as Lesson
	map_elements.add_child(lesson)
	# On the floor under where the master fell.
	var at: Vector2 = e["at"]
	lesson.global_position = cell_position(cell_at(at + Vector2(0, -8)))
	lesson.setup(self, cell)

# ------------------------------------------------------------------ lanterns

func light_lantern (lantern: Node) -> bool:
	if travelling or run_ending > 0.0 or not lantern.has_meta(&"cell") or is_lantern_spent(lantern):
		return false
	var was_vulnerable: bool = run.vulnerable
	snuffed = false
	_set_respawn(coord, lantern.get_meta(&"cell"))
	run.vulnerable = false
	_refresh_lanterns()
	# A lantern refills the hex's charges. Not mend's draughts nor resurrect's rites: only burning
	# a lantern fills those (burn_lantern).
	if player != null and player.has_node("Hex"):
		(player.get_node("Hex") as Hex).refill()
	if was_vulnerable:
		RisoFx.burst(&"gain", (lantern as Node2D).global_position, Vector2.ZERO, [Plate.EYE, Plate.GLOW])
	save_run()
	return true

## Whether the flame of the lantern the wizard carries is snuffed (MapInfo.snuff).
var snuffed: bool = false

## Put out the flame of the lantern the wizard carries (at a snuffing font, Snuffer, smoke rising
## from `at`) until they dash (Player) or light a lantern: it throws no light while it is out
## (Lamplight, RisoLight). Their lantern still protects them. Nothing happens while it is out
## already, or while they carry no lit flame (unprotected).
func snuff (at: Vector2) -> bool:
	if travelling or run_ending > 0.0 or not flame_lit():
		return false
	snuffed = true
	RisoFx.burst(&"gain", at, Vector2.UP, [Plate.NIGHT, Plate.BLUE])
	return true

## Light a snuffed flame again (a dash, see dash_switch).
func relight () -> void:
	if not snuffed:
		return
	snuffed = false
	if player != null and is_instance_valid(player):
		RisoFx.burst(&"gain", player.global_position + Vector2(0, -30), Vector2.ZERO, [Plate.EYE, Plate.GLOW])

## Douse the flame in the snuffing font at `cell` (Snuffer), its water at `at`, and take its
## darkness: the wizard gains every charge it holds (Snuffer.CHARGES in a font never touched, LARGE
## in a crypt's large one, or
## what was poured back into it), their flame goes out (if it burns), and the font is dry until
## darkness is poured into it again (LevelRecord.fonts, kept whatever befalls them after). Whether
## it gave any (a dry font gives nothing).
func douse_font (cell: Vector2i, at: Vector2) -> bool:
	var held: int = font_held(cell)
	if travelling or run_ending > 0.0 or held <= 0:
		return false
	record().fonts[cell] = 0
	run.dark_charges += held
	if not snuff(at):
		RisoFx.burst(&"gain", at, Vector2.UP, [Plate.NIGHT, Plate.BLUE])
	save_run()
	return true

## Pour every charge of darkness the wizard carries back into the dry snuffing font at `cell`
## (Snuffer), its water at `at`, to keep it there (LevelRecord.fonts) out of the way of the dash,
## which would spend it, and of a death; the next to douse their flame in it takes it all. How many
## were poured (none into a font still holding darkness).
func fill_font (cell: Vector2i, at: Vector2) -> int:
	var amount: int = run.dark_charges
	if travelling or run_ending > 0.0 or font_held(cell) > 0 or amount <= 0:
		return 0
	record().fonts[cell] = amount
	run.dark_charges = 0
	RisoFx.burst(&"gain", at, Vector2.DOWN, [Plate.NIGHT, Plate.BLUE])
	save_run()
	return amount

## The charges of darkness the snuffing font at `cell` here holds.
func font_held (cell: Vector2i) -> int:
	return int(record().fonts.get(cell, Snuffer.capacity(world, cell)))

## Whether the snuffing font at `cell` here has run dry.
func font_dry (cell: Vector2i) -> bool:
	return font_held(cell) <= 0

## Whether the ossuary door at `v` here has had its fill (OssuaryDoor): open for good.
func ossuary_open (v: Vector2i) -> bool:
	var how: Array = world.get_cell(v).extra_info
	return int(record().poured.get(int(how[0]), 0)) >= int(how[1])

## Pour the darkness the wizard carries into the ossuary doors of crypt `crypt` here, which open
## once `fill` charges are in (OssuaryDoor), the door at `at`: as many charges as they still want,
## kept by the record whatever befalls the wizard. How many were poured.
func pour_ossuary (crypt: int, fill: int, at: Vector2) -> int:
	if travelling or run_ending > 0.0:
		return 0
	var rec: LevelRecord = record()
	var before: int = int(rec.poured.get(crypt, 0))
	var amount: int = mini(run.dark_charges, fill - before)
	if amount <= 0:
		return 0
	run.dark_charges -= amount
	rec.poured[crypt] = before + amount
	RisoFx.burst(&"gain", at + Vector2(0, -20), Vector2.ZERO, [Plate.NIGHT, Plate.BLUE])
	if before + amount >= fill:
		RisoFx.burst(&"gain", at, Vector2.UP, [Plate.GLOW, Plate.ACCENT])
	save_run()
	return amount

## How long the flare of the last charge spent has left to burn (s; Lamplight.FLARE_TIME).
var flare: float = 0.0

## A dash (Player), in any world, while a lantern protects the wizard, switches their light by
## Rules.dash_dark: out of the dark it lights the flame and spends a charge, which flares
## (Lamplight.FLARE_REACH); while lit it puts the flame out again if a charge is left. With no
## charge it only lights a snuffed flame. So darkness carried out of the cemetery dwindles with
## every other dash, unless it is poured into a font to keep (fill_font).
func dash_switch () -> void:
	if run.vulnerable:
		relight()
		return
	var had: int = run.dark_charges
	var after: Vector2i = Rules.dash_dark(snuffed, had)
	run.dark_charges = after.y
	if snuffed and after.x == 0:
		relight()
		if after.y < had:
			flare = Lamplight.FLARE_TIME
	elif not snuffed and after.x == 1 and player != null and is_instance_valid(player):
		snuff(player.global_position + Vector2(0, -30))

## Whether the lantern the wizard carries burns: while a lantern protects them and it is not snuffed.
func flame_lit () -> bool:
	return not run.vulnerable and not snuffed

## Whether the lantern the wizard carries is out because they snuffed it, rather than because no
## lantern protects them: it is drawn cold and dark, not pink (RisoCostume, RisoWizard, RisoLight).
func flame_snuffed () -> bool:
	return run != null and not run.vulnerable and snuffed

func is_lantern_spent (lantern: Node) -> bool:
	return lantern.has_meta(&"cell") and record().spent_lanterns.has(lantern.get_meta(&"cell"))

func is_respawn_lantern (lantern: Node) -> bool:
	return not run.vulnerable and coord == run.respawn_coord and lantern.has_meta(&"cell") and lantern.get_meta(&"cell") == run.respawn_cell and not is_lantern_spent(lantern)

func _refresh_lanterns () -> void:
	if is_instance_valid(map_elements):
		for node: Node in map_elements.get_children():
			if node is Checkpoint:
				(node as Checkpoint).refresh()

## True when the last lit lantern is in another level (the player must travel to respawn).
func respawn_elsewhere () -> bool:
	return world != null and run.respawn_coord != coord

func _set_respawn (at: Vector2i, cell: Vector2i) -> void:
	run.respawn_coord = at
	run.respawn_cell = cell
	if respawn_marker == null:
		respawn_marker = Node2D.new()
		respawn_marker.name = "RespawnMarker"
		main.add_child(respawn_marker)
	respawn_marker.global_position = cell_position(cell)
	if player != null:
		player.respawn = respawn_marker

# ------------------------------------------------------------------ death, the ghost, the end

## Give up (the pause menu), when stuck: only while a lantern protects the wizard. It is a death
## like any other: the stars drop into a ghost and the lantern burns out, bringing them back to it.
func can_give_up () -> bool:
	return player != null and world != null and not run.vulnerable and not travelling and run_ending <= 0.0

func give_up () -> bool:
	if not can_give_up():
		return false
	player.die()
	return true

## A lit lantern absorbs one death, burns out, and brings the wizard back to its location at full
## health. Without another lit lantern, the next death ends the run. The stars they carried drop into
## a ghost, which keeps the lantern the death burned out (recover_ghost).
func player_died (pos: Vector2) -> void:
	if run_ending > 0.0 or travelling:
		return
	if run.vulnerable:
		end_run()
		return
	player.health.health = player.health.max_health
	_clear_ghost()
	run.leave_ghost(coord, pos, player.coins.coins, [run.respawn_coord, run.respawn_cell])
	player.collect(-run.ghost_stars)
	run.spend_lantern(run.respawn_coord, run.respawn_cell)
	run.vulnerable = true
	_refresh_lanterns()
	run.revive_slain()
	save_run()
	# The respawn level reloads, so its enemies are back (and the ghost appears if it is there).
	respawn_in_other_level()

## Touching the ghost returns its stars and the darkness it holds, and relights the lantern its death burned out: lit again,
## it protects the next death, and, while the wizard has no other lantern lit, it is theirs again (as
## it was, their respawn). It does not heal (the wizard came back at full health).
func recover_ghost () -> void:
	if not run.has_ghost:
		return
	var stars: int = run.ghost_stars
	var charges: int = run.ghost_charges
	var at: Vector2 = run.ghost_pos
	var lantern: Array = run.ghost_lantern
	_clear_ghost()
	player.collect(stars)
	run.dark_charges += charges
	if lantern.size() == 2:
		run.record(lantern[0]).spent_lanterns.erase(lantern[1])
		if run.vulnerable and run.respawn_coord == lantern[0] and run.respawn_cell == lantern[1]:
			run.vulnerable = false
		_refresh_lanterns()
	RisoFx.burst(&"gain", at, Vector2.ZERO, [Plate.GLOW, Plate.ACCENT])
	save_run()

## The run is over: show the card, then start again at depth 0 of the run's seed with a fresh
## character and no records (the levels themselves are unchanged).
func end_run () -> void:
	if run_ending > 0.0:
		return
	Known.note(run, coord, world, loader.laid_out)
	RunState.delete_save()
	_unsaved = false
	run_ending = RUN_END_SECONDS
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.visible = false
	while run_ending > 0.0:
		await get_tree().process_frame
		run_ending = maxf(0.0, run_ending - get_process_delta_time())
	player.collect(-player.coins.coins)
	player.keyring.clear()
	player.visible = true
	start_run(run.run_seed)

## Every boss's trophy is on its stand (set_trophy): the run is won. The wizard stops where they
## stand, the card of a won run shows (RisoHud) until a press made once it has shown WIN_HOLD
## seconds, and the start menu comes back with the save gone, so the next run begins afresh; the
## win is kept past it (Trophy.note_won), for the menu to show the trophies.
func win_run () -> void:
	if run_ending > 0.0:
		return
	won = true
	Trophy.note_won(Bands.bosses())
	Known.note(run, coord, world, loader.laid_out)
	RunState.delete_save()
	_unsaved = false
	run_ending = 1.0
	won_for = 0.0
	_won_pressed = false
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	while not _won_pressed and is_inside_tree():
		await get_tree().process_frame
		won_for += get_process_delta_time()
	var menu: Menu = Stage.menu() as Menu
	if menu != null and is_inside_tree():
		menu.return_to_menu()

## The worm's rumble in the levels near it (WormSign), with the level's other things.
func _spawn_worm_sign () -> void:
	if map_elements == null or not is_instance_valid(map_elements) or here == null or here.archetype != &"garden":
		return
	var sign: WormSign = WormSign.new()
	sign.name = "WormSign"
	map_elements.add_child(sign)

func _spawn_ghost () -> void:
	if not run.has_ghost or run.ghost_coord != coord or map_elements == null or not is_instance_valid(map_elements):
		return
	if ghost_node != null and is_instance_valid(ghost_node):
		ghost_node.queue_free()
	ghost_node = Prefabs.make(GHOST) as Node2D
	ghost_node.position = run.ghost_pos
	(ghost_node as Ghost).stars = run.ghost_stars
	map_elements.add_child(ghost_node)

func _clear_ghost () -> void:
	run.clear_ghost()
	if ghost_node != null and is_instance_valid(ghost_node):
		ghost_node.queue_free()
	ghost_node = null

# ------------------------------------------------------------------ saving

## Autosaved on arriving in a level, lighting a lantern, dying, recovering the ghost, taking a
## key, using a shrine, pausing and quitting. Stars picked up since the last save can be lost.
## Whatever changes the run calls this: it only marks the run as changed, and the save is written
## once, as the frame is processed (_process), so a frame in which a dozen things change writes
## the file once. What must be on disk before going on (pausing, quitting, leaving for the menu)
## calls save_now.
func save_run () -> void:
	_unsaved = true

## Whether the run has changed since its save was last written (save_run).
var _unsaved: bool = false

## Write the run's save at once, and note what the run knows in the kept map (Known.note): on
## pausing, quitting, closing the window and leaving the scene, where the next frame may not come.
func save_now () -> void:
	if _write_run():
		Known.note(run, coord, world, loader.laid_out)

## Write the run's save (RunState.write_save, whole or not at all). False while there is no run to
## save: before the first level is in the scene, or once the run has ended.
func _write_run () -> bool:
	_unsaved = false
	if player == null or not is_instance_valid(player) or world == null or run_ending > 0.0:
		return false
	RunState.write_save(run.to_save(coord, player.to_save()))
	return true

## Resume the saved run at its last lit lantern. False when there is nothing to continue.
func continue_run () -> bool:
	if _unsaved:
		_write_run()
	var data: Dictionary = RunState.read_save()
	if data.is_empty():
		return false
	wizard()
	_clear_ghost()
	run.from_save(data)
	player.from_save(data)
	coord = run.respawn_coord
	arrival = -2
	_load_level()
	return true

# ------------------------------------------------------------------ what the map has seen
# Each level's record keeps a byte per cell: 1 once seen. The player sees a few cells around
# them as they move; a moon shard shows a whole chunk. The printed map (RisoMap) draws from it.

const SEE_RADIUS: int = 5
## Bumped whenever something new is seen, so the map knows to redraw.
var seen_version: int = 0
var _last_seen_cell: Vector2i = Vector2i(-9999, -9999)

## What has been seen of the level being played: a byte per cell (see LevelRecord.seen).
func seen () -> PackedByteArray:
	return _seen()

func _seen () -> PackedByteArray:
	return record().seen_for(world.size.x * world.size.y if world != null else 0)

func is_seen (v: Vector2i) -> bool:
	if world == null or not world.is_valid(v):
		return false
	return _seen()[v.x * world.size.y + v.y] != 0

func seen_count () -> int:
	var n: int = 0
	for b: int in _seen():
		n += b
	return n

## Mark every cell within `radius` of `at` as seen.
func reveal (at: Vector2i, radius: int = SEE_RADIUS) -> void:
	if world == null:
		return
	var bytes: PackedByteArray = _seen()
	var changed: bool = false
	for x: int in range(at.x - radius, at.x + radius + 1):
		for y: int in range(at.y - radius, at.y + radius + 1):
			var v: Vector2i = Vector2i(x, y)
			if world.is_valid(v) and (v - at).length_squared() <= radius * radius:
				var i: int = x * world.size.y + y
				if bytes[i] == 0:
					bytes[i] = 1
					changed = true
	if changed:
		record().seen = bytes
		seen_version += 1

## The ink well: the whole level inked onto the map at once.
func ink_whole_map () -> void:
	if world == null:
		return
	_seen().fill(1)
	record().mapped = true
	seen_version += 1
	save_run()

# ------------------------------------------------------------------ where things are

func cell_position (v: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(v))

## The level cell a world position falls in.
func cell_at (pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(pos))

## The level's area in world pixels (its cells, not the rock border round them).
func level_rect () -> Rect2:
	var cell: Vector2 = Vector2(tile_map.tile_set.tile_size) * tile_map.global_scale
	var top_left: Vector2 = cell_position(Vector2i.ZERO) - cell * 0.5
	return Rect2(top_left, Vector2(world.size) * cell if world != null else cell)

## `v` (world pixels) kept within the centres of the level's corner cells.
func clamp_bounds (v: Vector2) -> Vector2:
	var lo: Vector2 = cell_position(Vector2i.ZERO)
	var hi: Vector2 = cell_position(world.size - Vector2i.ONE)
	return v.clamp(lo, hi)

## Whether world position `pos` is inside something solid: rock (or outside the level), cracked
## rock not yet broken (a secret's false wall aside), or a shut door or gate.
func solid_at (pos: Vector2) -> bool:
	if world == null:
		return false
	var v: Vector2i = cell_at(pos)
	if not world.is_valid(v):
		return true
	var cell: LevelGen.Cell = world.get_cell(v)
	var rec: LevelRecord = record()
	match cell.type:
		LevelGen.Type.GROUND:
			return true
		LevelGen.Type.CRACKED:
			if rec.broken.has(v):
				return false
			return cell.extra_info == null or not (world.secrets[int(cell.extra_info)]["entrance"] as Array).has(v)
		LevelGen.Type.DOOR, LevelGen.Type.TRAPDOOR:
			return not rec.opened.has(v)
		LevelGen.Type.SWITCH_GATE:
			return not gate_open(v)
		LevelGen.Type.LIGHT_GATE:
			return not bool(light_gates.get(v, false))
		LevelGen.Type.OSSUARY_DOOR:
			return not ossuary_open(v)
		LevelGen.Type.EXAM_DOOR:
			return not bool(institute.exam_doors.get(v, true))
	return false

## Whether `event` is a press of a key, a pad's button or the mouse (not one held down repeating).
static func _a_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventAction:
		return event.is_pressed()
	return false

func _physics_process (delta: float) -> void:
	if world != null and run_ending <= 0.0:
		run.play_time += delta
	institute.tick(delta)
	flare = maxf(0.0, flare - delta)
	if world == null or travelling or player == null or not is_instance_valid(player):
		return
	gust_clock += delta
	var c: Vector2i = cell_at(player.global_position)
	if c != _last_seen_cell:
		_last_seen_cell = c
		reveal(c)
		# Stepping into a secret room's false wall (or drifting or warping into its rock) opens it.
		open_secret(secret_at(c))
	institute.step()
	loader.sleep_far_chunks()

func _input(event: InputEvent) -> void:
	if won and run_ending > 0.0 and won_for >= WIN_HOLD and _a_press(event):
		_won_pressed = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("Debug-Back") and dev_tools():
		travel(Exit.BACK)
