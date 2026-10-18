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
enum Exit { DEEPER, BACK, LEFT, RIGHT, RETURN }

## Debug runs (from the start menu): every exit is generated right by the spawn, and the run
## starts with DEBUG_STARS. Saved with the run and shown in the HUD.
static var debug: bool = false
const DEBUG_STARS: int = 9999

static var instance: MapInfo

@onready var wfc: WaveFunctionCollapse = $"../../WaveFunctionCollapse"
@onready var tile_map: TileMap = $"../../TileMap"
@onready var main: Node = Stage.main()
var player: Player

## What the run remembers (see RunState), and what puts places in the scene (see LevelLoader).
var run: RunState = RunState.new()
var loader: LevelLoader

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
const GHOST: PackedScene = preload("res://prefabs/corpse.tscn")
## Seconds left on the end-of-run card (0 while playing).
var run_ending: float = 0.0
const RUN_END_SECONDS: float = 3.0


func _enter_tree() -> void:
	instance = self
	if loader == null:
		loader = LevelLoader.new(self)
		loader.ready_to_build.connect(_level_ready)
		add_child(loader)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()


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
const SOLD_KEY_DEAL: int = 6200

## A shrine sold a skeleton key: it is laid on a floor of this level, dealt by the level seed, at
## least SOLD_KEY_APART cells from the shrine where there is such a floor (never in a vault). It is
## kept as a dropped key (the record keeps it until taken, and the map shows it). Returns where.
func lay_sold_skeleton () -> Vector2:
	var vaulted: Dictionary = {}
	for vault: Dictionary in world.vaults:
		for c: Vector2i in vault["room"]:
			vaulted[c] = true
	var floors: Array[Vector2i] = world.free_floors().filter(func(v: Vector2i) -> bool: return not vaulted.has(v))
	var far: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, world.shrine) >= SOLD_KEY_APART)
	var pool: Array[Vector2i] = far if not far.is_empty() else floors
	var at: Vector2i = pool[Rules.level_seed(Rules.level_seed(coord.x, coord.y), SOLD_KEY_DEAL) % pool.size()] if not pool.is_empty() else world.shrine
	var pos: Vector2 = cell_position(at)
	var id: int = record().drop_key(pos, KeyRing.SKELETON)
	_spawn_dropped_key(id, pos, KeyRing.SKELETON)
	save_run()
	return pos

func _spawn_dropped_key (id: int, pos: Vector2, color: int) -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var key: Node2D = Placeables.scene(LevelGen.Type.KEY).instantiate()
	key.set_meta(&"key_color", color)
	key.set_meta(&"dropped_id", id)
	key.position = pos
	map_elements.add_child(key)

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

## Boss `boss` died at `pos` (Boss): slain for the rest of the run, so every gate level of its band
## opens; where it fell, its relic waits (Bosses.relic_for, free), or, with every move known, a
## skeleton key and a star cluster.
func boss_slain (boss: StringName, pos: Vector2) -> void:
	if boss == &"" or run.bosses.has(boss):
		return
	run.bosses[boss] = true
	# The beast's souls go with it.
	if boss == &"beast":
		BeastSouls.end(run)
	var move: StringName = Bosses.relic_for(boss, run.run_seed, player)
	if move != &"":
		run.boss_relics[boss] = [coord, pos, move]
		_spawn_boss_relics()
	else:
		var id: int = record().drop_key(pos, KeyRing.SKELETON)
		_spawn_dropped_key(id, pos, KeyRing.SKELETON)
		var cluster: Coin = Placeables.scene(LevelGen.Type.CLUSTER).instantiate() as Coin
		cluster.value = Rules.cluster_value(here.depth)
		map_elements.add_child(cluster)
		cluster.global_position = pos + Vector2(60, -40)
	RisoFx.burst(&"gain", pos, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])
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
	RisoFx.burst(&"gain", player.global_position if wizard() != null else Vector2.ZERO, Vector2.ZERO, [RisoPrint.PINK, RisoPrint.NIGHT])
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

## The whale's open mouth took the wizard in: into its belly (Belly), at its way back.
func enter_belly () -> void:
	if travelling or run_ending > 0.0:
		return
	var to: Vector2i = Worlds.side_at(Worlds.kind_of(Belly), coord)
	await _pass(Vector2.RIGHT, to)
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
## bramble, the spider, or a stand-in) dies as by any blow, leaving its relic; else the boss whose
## gate this is, if it lives (it has no place to stand here), is slain where the wizard stands.
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
			if node is Spider and not (node as Spider).slain:
				(node as Spider).slay()
				return true
			if node is Necromancer and not (node as Necromancer).slain:
				(node as Necromancer).slay()
				return true
			if node is Beast and not (node as Beast).slain:
				(node as Beast).slay()
				return true
			if node is Boss:
				(node as Boss).slay()
				return true
			if node is WhaleHeart:
				(node as WhaleHeart).slay()
				return true
			if node is Whale:
				boss_slain(&"whale", (node as Whale).global_position + Vector2(0, 300))
				node.queue_free()
				return true
	var gate: StringName = here.gate if here != null else &""
	if gate != &"" and not run.bosses.has(gate) and player != null:
		boss_slain(gate, player.global_position)
		return true
	return false

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
	if Placeables.has_flag(world.get_cell(above).type, &"stander"):
		return true
	# The shrine stands across two cells: its own and the one to its right.
	var left: Vector2i = above + Vector2i.LEFT
	return world.is_valid(left) and world.get_cell(left).type == LevelGen.Type.SHRINE

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
	RisoFx.burst(&"gain", middle, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	RisoFx.burst(&"hit", middle, Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
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
	RisoFx.burst(&"gain", pos, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])
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

## A shrine's hint: mark that relic on the worlds map. Returns its level, or null.
func hint_relic () -> Variant:
	var at: Variant = run.hint_relic(coord)
	if at != null:
		save_run()
	return at

# ------------------------------------------------------------------ moving between places

## Begin a run at depth 0 of `run_seed`; its start lantern is lit.
func start_run (seed_value: int) -> void:
	run.start(seed_value)
	coord = Vector2i(seed_value, 0)
	arrival = -1
	region = &""
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
	coord = run.respawn_coord
	arrival = -2
	_load_level()

## Load place `to`, arriving at `how` (an exit there, or -3 for arrival_pos). Coming into a sky
## level, the whale moves (WhaleHunt.move).
func _arrive (to: Vector2i, how: int) -> void:
	coord = to
	run.reached(coord)
	WhaleHunt.move(run, coord)
	arrival = how
	_load_level()

## The region (a band's archetype name) the wizard was last in, for its title card; none before a
## run's first level is built, so the run opens on one.
var region: StringName = &""

## Coming into a region from another (or at a run's start): its title card (RisoTransition.title).
## A side world is no region of its own: going into one and back shows none.
func _title_region () -> void:
	if Worlds.is_side(coord) or here == null or here.arch == null:
		return
	var now: StringName = here.arch.name
	if now == region:
		return
	region = now
	if RisoTransition.instance != null:
		RisoTransition.instance.title(here.arch.title)

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
	exam_doors.clear()
	last_tower = -1
	_deal_stations()
	loader.build(world)
	var rec: LevelRecord = record()
	# Secret rooms already opened: their rewards (the rest of the room stays broken, see
	# open_secret). After everything else, so the rest of the level lands where it always has.
	for id: int in rec.secrets:
		_spawn_secret_rewards(id)
	for id: int in rec.dropped:
		_spawn_dropped_key(id, rec.dropped[id][0], rec.dropped[id][1])
	Rift.restore(self)
	_spawn_boss_relics()
	_spawn_left_relics()
	_spawn_whale()
	_spawn_souls()
	_spawn_lessons()
	_lay_papers()
	_spawn_way_back()
	# Rock broken before, under things you stand at: their ledges.
	_props.clear()
	prop_up(rec.broken.keys())
	_spawn_ghost()
	_arrived()

## The place is in the scene: lay its rock, put the wizard at the way in, and carry on.
func _arrived () -> void:
	loader.lay_terrain(world, here.open())
	_last_seen_cell = Vector2i(-9999, -9999)
	class_hall = -1
	_outside_at = Vector2.INF
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
	if arrival == -1:
		_set_respawn(coord, world.exit_lanterns.get(Exit.BACK, at))
	elif arrival == -2:
		at = run.respawn_cell
		_set_respawn(coord, run.respawn_cell)
	elif arrival == ARRIVE_BALLOON and world.is_valid(world.balloon):
		at = world.balloon
	elif arrival == ARRIVE_WAY_BACK and run.way_back.size() >= 4 and run.way_back[0] == coord and run.way_back[1] != Vector2.INF:
		at = cell_at(run.way_back[1])
	if player != null:
		player.position = arrival_pos if arrival == -3 else cell_position(at)
		player.velocity = Vector2.ZERO
		player.set_collision(true)
		player.set_physics_process(true)
		player.grace()
		if _from_department:
			class_hall = Timetable.hall_inside(world, at if arrival != -3 else cell_at(arrival_pos))
		# A trip (through a portal, or a warp) cut short by a death or a run's end never got to show
		# the wizard again, and its portal is gone with the old level: end it here.
		if player.has_meta(&"portal_trip"):
			player.remove_meta(&"portal_trip")
		RisoPrint.portal_reveal(player)
	_from_department = false
	travelling = false
	if _slay_on_arrival != &"":
		var on: Vector2i = world.exits.get(Exit.DEEPER, at)
		boss_slain(_slay_on_arrival, cell_position(on) + Vector2(-140.0, 0.0))
		_slay_on_arrival = &""
	_refresh_lanterns()
	if RisoPrint.instance != null:
		RisoPrint.instance.world_built(self, coord.y)
	if RisoTransition.instance != null:
		RisoTransition.instance.reveal()
	_title_region()
	save_run()
	# The new level wakes around the wizard (the camera catches up next frame).
	loader.wake_around(player.global_position if player != null else Vector2.INF)
	loader.prefetch_neighbours(here)

## Another place's layout, for the map: the place being played, or one laid out from its seed.
## Null while the generator is busy (try again next frame).
func world_at (at: Vector2i) -> LevelGen:
	if at == coord and world != null:
		return world
	return loader.world_at(at)

# ------------------------------------------------------------------ the institute

## The hall doors of the level being played (ExamDoor), by cell: whether each is up now.
var exam_doors: Dictionary = {}

## A classroom's master (Scholar.instructor) fell to the wizard's own blow at `pos`, teaching `a`: it
## leaves a paper of `a` at the spell's top tier, once a classroom (`hall`, LevelRecord.prizes), if the
## institute teaches `a` to the wizard (teaches). The prize for beating a class at its strongest, and
## stolen (KeyRing.stolen). Teaching a big move the wizard has not found (Relics.MOVES), it leaves
## that move's relic instead (relic_left).
func instructor_fell (hall: int, pos: Vector2, a: StringName) -> void:
	var rec: LevelRecord = record()
	if a == &"" or rec.prizes.has(hall):
		return
	rec.prizes[hall] = true
	# A big move the wizard has not found: its relic, so the institute can be where it is found.
	if not teaches(a):
		relic_left(pos, a, false)
		return
	var code: int = KeyRing.stolen(KeyRing.paper(a, Abilities.max_tier(a)))
	_spawn_dropped_key.call_deferred(rec.drop_key(pos, code), pos, code)
	save_run()

## At a lit lantern (Checkpoint), at `at`: the oldest paper carried that teaches something
## (learn_paper) is learned. Returns whether one was.
func study (at: Vector2) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for code: int in player.keyring.papers():
		if learn_paper(code, at):
			return true
	return false

## Exam paper `code` learned, at `at`: its spell takes its slot at the paper's tier, and the spell it
## puts out of the slot comes back as a paper (put_back). A paper of the spell already held, at a tier
## no higher than it is known, teaches nothing (and stays on the ring). Returns whether it taught.
func learn_paper (code: int, at: Vector2) -> bool:
	var a: StringName = KeyRing.paper_spell(code)
	var tier: int = KeyRing.paper_tier(code)
	if a == &"" or Abilities.slot_of(a) == &"":
		return false
	var held: StringName = Abilities.spell(player, Abilities.slot_of(a))
	if held == a and Abilities.tier(player, a) >= tier:
		return false
	var held_tier: int = Abilities.tier(player, held) if held != &"" else 0
	player.keyring.spend(code)
	Abilities.set_tier(player, a, tier)
	if held != &"" and held != a:
		put_back(held, held_tier, at)
	RisoFx.burst(&"gain", at, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.GLOW])
	Wound.shake(6.0, 0.15)
	save_run()
	return true

## Spell `a`, known at `tier`, put out of its slot (a lantern's study, a shrine's boon, a lesson): it
## comes back as an exam paper (KeyRing.paper), onto the key ring (one put off a full ring is left
## lying at `at`).
func put_back (a: StringName, tier: int, at: Vector2) -> void:
	if a != &"" and tier > 0:
		give_paper(KeyRing.paper(a, tier), at)

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

# ------------------------------------------------------------------ the timetable

## The physics frame a bell was last rung in (a spell that rings one is not held against the wizard).
var _rung_frame: int = -1
## The great bell: how long it rings out once rung (seconds), the institute shaking with it at first
## as hard as BELL_SHAKE (px) and less as it fades; and the seconds since it was last rung (the art).
const BELL_TIME: float = 3.0
const BELL_SHAKE: float = 5.0
var since_bell: float = 99.0
## How much more the abominations act up in passing time with each ring in their level: their
## breaches, growth and launches that much sooner a ring (Abomination, Breach).
const SURGE_PER_RING: float = 0.5
## Field papers: how far (cells) from a field level's way in its waiting papers lie, at least (where
## the level allows), and the salt for the run seed that deals their floors.
const PAPER_CLEAR: int = 10
const PAPER_DEAL: int = 6600
## A lectern's paper lifted in a period is kept by its hall and the rings (LevelRecord.lifted): this
## many rings to a hall.
const LIFT_KEY: int = 10000
## No field level (a hall with no department's portal).
const NO_FIELD: Vector2i = Vector2i(-99999, -99999)

## Whether the level being played keeps the institute's timetable (Timetable.kept_in).
func timetabled () -> bool:
	return world != null and Timetable.kept_in(world)

## Whether the wizard is where they belong now (Timetable.belongs): false wherever there is no
## timetable, and anywhere while they carry a stolen paper (KeyRing.is_stolen).
func wizard_belongs () -> bool:
	if world == null or player == null or not is_instance_valid(player):
		return false
	if player.keyring.papers().any(func(code: int) -> bool: return KeyRing.is_stolen(code)):
		return false
	var rec: LevelRecord = record()
	var at: Vector2i = cell_at(player.global_position)
	if not Timetable.belongs(world, rec.rings, rec.passing, at):
		return false
	var hall: int = Timetable.hall_inside(world, at)
	return hall < 0 or world.halls[hall]["kind"] != &"lecture" or enrolled(hall)

## Whether the wizard is enrolled in lecture hall `hall`'s class now (Timetable.needs): it has a
## class, and asks for nothing, or for a department whose subject they hold in a slot, or carry as an
## exam paper, at the tier it needs or higher; and in the classroom holding the way on, they carry its
## paper besides (way_on_paper).
func enrolled (hall: int) -> bool:
	var a: StringName = subject_of(hall)
	if a == &"" or player == null or not is_instance_valid(player):
		return false
	if hall == Timetable.way_on_hall(world) and not way_on_paper():
		return false
	var need: Array = Timetable.needs(world.halls[hall]["dept"], tier_of(hall))
	if need[0] == &"":
		return true
	for b: StringName in Timetable.LADDERS[need[0]]:
		if Abilities.tier(player, b) >= int(need[1]):
			return true
	return player.keyring.papers().any(func(code: int) -> bool: return Timetable.dept_of(KeyRing.paper_spell(code)) == need[0] and KeyRing.paper_tier(code) >= int(need[1]))

## Whether the wizard carries what the classroom holding the way on asks for besides its class's own
## prerequisite: an exam paper (not a spell held) of any department but that classroom's, at
## Timetable.WAY_ON_PAPER or higher. True where there is no such classroom.
func way_on_paper () -> bool:
	var hall: int = Timetable.way_on_hall(world)
	if hall < 0:
		return true
	for code: int in player.keyring.papers():
		var dept: StringName = Timetable.dept_of(KeyRing.paper_spell(code))
		if dept != &"" and dept != world.halls[hall]["dept"] and KeyRing.paper_tier(code) >= Timetable.WAY_ON_PAPER:
			return true
	return false

## What lecture hall `hall` teaches now (Timetable.subject; &"" for no class), and at what tier.
func subject_of (hall: int) -> StringName:
	return Timetable.subject(world, hall, record().rings) if world != null else &""

func tier_of (hall: int) -> int:
	var a: StringName = subject_of(hall)
	return Timetable.tier_taught(a, int(dept_tiers()[world.halls[hall]["dept"]])) if a != &"" else 0

## Whether the great bell can ring now: at every pull of a cord, in a period or in passing time (each
## ring moves every class on), but not within SchoolBell.RING_GAP of its last ring.
func bell_ready () -> bool:
	return timetabled() and since_bell >= SchoolBell.RING_GAP

## The great bell was rung (one of its cords pulled, SchoolBell), if it can be (bell_ready): a wizard
## in a class as it rings has attended it (_attend); the level moves on a period and passing time
## begins; every class is seated afresh (_seat_classes) and every scholar calms down; the beast is fed
## (RunState.fed); and the institute shakes while the bell rings out (BELL_TIME). Returns whether it
## rang.
func ring_period () -> bool:
	if not bell_ready():
		return false
	var attended: StringName = _attend()
	_rung_frame = Engine.get_physics_frames()
	since_bell = 0.0
	Wound.shake(BELL_SHAKE, BELL_TIME)
	var rec: LevelRecord = record()
	rec.dept_tiers = Timetable.climb(dept_tiers(), attended, _meeting())
	rec.rings += 1
	rec.passing = true
	run.fed += 1
	_seat_classes()
	for node: Node in get_tree().get_nodes_in_group(&"scholar"):
		(node as Scholar).calm()
	save_run()
	return true

## Every department's tier in the level now (LevelRecord.dept_tiers, I for one not yet climbed).
func dept_tiers () -> Dictionary:
	var out: Dictionary = {}
	for dept: StringName in Timetable.LADDERS:
		out[dept] = int(record().dept_tiers.get(dept, 1))
	return out

## Which departments meet in this level now (department -> whether it has a classroom here and
## meets this period, Timetable.meets).
func _meeting () -> Dictionary:
	var out: Dictionary = {}
	var rings: int = record().rings
	for dept: StringName in Timetable.LADDERS:
		out[dept] = Institute.first_of(world, dept) >= 0 and Timetable.meets(dept, rings)
	return out

## The wizard rang the period out inside a lecture hall's class: they attended it, if the class was
## theirs to attend: one they started by going into it (_watch_timetable), its master there and not
## turned on them (beaten or crossed, it expels them). One whose subject the institute cannot teach
## them (teaches: a relic's move they lack) counts all the same, with no paper. A paper of its
## subject carried at a lower tier is graded up to the tier taught, there in hand (resitting);
## otherwise its exam paper (its subject at the tier taught, KeyRing.paper) waits in the level its
## department's portal leads to (field_of; RunState.papers_out, laid there by _lay_papers). Returns the
## department attended (what the departments climb by, Timetable.climb), or &"" for none.
func _attend () -> StringName:
	if player == null or not is_instance_valid(player):
		return &""
	var hall: int = Timetable.hall_inside(world, cell_at(player.global_position))
	if hall < 0 or world.halls[hall]["kind"] != &"lecture":
		return &""
	var a: StringName = subject_of(hall)
	var m: Scholar = master_in(hall)
	var to: Vector2i = field_of(hall)
	if a == &"" or m == null or m.roused or record().passing or class_hall != hall:
		return &""
	var dept: StringName = world.halls[hall]["dept"]
	if not teaches(a):
		return dept
	var tier: int = tier_of(hall)
	for code: int in player.keyring.papers():
		if KeyRing.paper_spell(code) == a and KeyRing.paper_tier(code) < tier:
			player.keyring.replace(code, KeyRing.paper(a, tier))
			RisoFx.burst(&"gain", player.global_position + Vector2(0, -60), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.GLOW])
			return dept
	if to != NO_FIELD:
		var waiting: Array = run.papers_out.get(to, [])
		waiting.append(KeyRing.paper(a, tier))
		run.papers_out[to] = waiting
		RisoFx.burst(&"gain", player.global_position + Vector2(0, -60), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	return dept

## The level lecture hall `hall`'s department's portal leads to (Department, in the first classroom
## of the department, Institute.first_of), or NO_FIELD.
func field_of (hall: int) -> Vector2i:
	var dept: StringName = world.halls[hall]["dept"]
	for v: Vector2i in world.objects_of(LevelGen.Type.DEPARTMENT):
		var extra: Array = world.get_cell(v).extra_info as Array
		if StringName(extra[0]) == dept:
			return Vector2i(coord.x, int(extra[1]))
	return NO_FIELD

## The exam papers waiting in this level (RunState.papers_out, from classes attended), laid on its
## floors as keys left lying are (LevelRecord.dropped), each at least PAPER_CLEAR cells from the way in
## where the level allows, dealt by the run seed.
func _lay_papers () -> void:
	var waiting: Array = run.papers_out.get(coord, [])
	if waiting.is_empty() or world == null:
		return
	run.papers_out.erase(coord)
	var start: Vector2i = world.exits.get(Exit.BACK, Vector2i(-1, -1))
	var floors: Array[Vector2i] = world.free_floors()
	var far: Array[Vector2i] = floors.filter(func(v: Vector2i) -> bool: return LevelGen.dist(v, start) >= PAPER_CLEAR)
	if far.is_empty():
		far = floors
	if far.is_empty():
		return
	var rec: LevelRecord = record()
	for k: int in range(waiting.size()):
		var code: int = waiting[k]
		var v: Vector2i = far[posmod(Rules.level_seed(run.run_seed, PAPER_DEAL + code * 31 + k + coord.x * 977 + coord.y * 131), far.size())]
		var at: Vector2 = cell_position(v)
		_spawn_dropped_key(rec.drop_key(at, code), at, code)
	save_run()

## Sneaking: the exam paper lecture hall `hall`'s lectern holds while the hall is empty (its class
## away): its next class's, at the tier taught after the next ring, once a period (LevelRecord.lifted),
## and only one the institute teaches the wizard; else 0.
func lectern_paper (hall: int) -> int:
	if world == null or hall < 0 or hall >= world.halls.size() or world.halls[hall]["kind"] != &"lecture" or subject_of(hall) != &"":
		return 0
	var rec: LevelRecord = record()
	if rec.lifted.has(hall * LIFT_KEY + rec.rings):
		return 0
	var next: StringName = Timetable.subject(world, hall, rec.rings + 1)
	if next == &"" or not teaches(next):
		return 0
	return KeyRing.paper(next, Timetable.tier_taught(next, int(dept_tiers()[world.halls[hall]["dept"]])))

## The paper on lecture hall `hall`'s lectern now: one left there (LevelRecord.pigeonholes), else,
## while the room is empty, the next class's (lectern_paper); 0 for none.
func lectern_slot (hall: int) -> int:
	var rec: LevelRecord = record()
	if rec.pigeonholes.has(hall):
		return int(rec.pigeonholes[hall])
	var code: int = lectern_paper(hall)
	return code if code != 0 and not player.keyring.has(code) else 0

## Lecture hall `hall`'s lectern used from `at`: the paper the wizard picked up last goes onto it, and
## the one it held (lectern_slot) comes onto the ring; either may be missing. A next class's paper
## lifted is gone from it for the period (LevelRecord.lifted), and stolen (KeyRing.stolen).
func lectern_swap (hall: int, at: Vector2) -> void:
	var rec: LevelRecord = record()
	var held: int = lectern_slot(hall)
	var papers: Array[int] = player.keyring.papers()
	var mine: int = papers[-1] if not papers.is_empty() else 0
	if (held == 0 and mine == 0) or held == mine:
		return
	if held != 0 and not rec.pigeonholes.has(hall):
		rec.lifted[hall * LIFT_KEY + rec.rings] = true
		held = KeyRing.stolen(held)
	if mine != 0:
		player.keyring.spend(mine)
		rec.pigeonholes[hall] = mine
	else:
		rec.pigeonholes.erase(hall)
	if held != 0:
		give_paper(held, at)
	else:
		save_run()

## Exam paper `code` taken at `at`: onto the ring, as a key is (one put off a full ring is left
## lying at `at`, KeyRing.take).
func give_paper (code: int, at: Vector2) -> void:
	var had: int = player.keyring.take(code)
	if had >= 0:
		var rec: LevelRecord = record()
		var id: int = rec.drop_key(at, had)
		_spawn_dropped_key.call_deferred(id, at, had)
	RisoFx.burst(&"gain", at + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	save_run()

## Whether the scholar laid at cell `v` is away now: one of a lecture hall's class while the hall has
## no class (LevelLoader.place_cell leaves it out).
func class_away (v: Vector2i) -> bool:
	if not timetabled():
		return false
	var hall: int = Timetable.hall_inside(world, v)
	return hall >= 0 and world.halls[hall]["kind"] == &"lecture" and subject_of(hall) == &""

## Every lecture hall's class seated afresh, as the bell has just rung: whoever was in it goes (a
## fallen master or student is not slain any more), and, where the hall has a class now, its master
## and its students are placed again, the master teaching the hall's new subject.
func _seat_classes () -> void:
	if map_elements == null or not is_instance_valid(map_elements):
		return
	var rec: LevelRecord = record()
	for i: int in range(world.halls.size()):
		if world.halls[i]["kind"] != &"lecture":
			continue
		var box: Rect2i = world.halls[i]["box"]
		for node: Node in get_tree().get_nodes_in_group(&"scholar"):
			var s: Scholar = node as Scholar
			if s != null and box.has_point(s.cell) and not s.is_queued_for_deletion():
				s.get_parent().remove_child(s)
				s.queue_free()
		for v: Vector2i in world.objects:
			if box.has_point(v) and world.get_cell(v).type in [LevelGen.Type.MASTER, LevelGen.Type.STUDENT, LevelGen.Type.PROCTOR]:
				rec.slain.erase(v)
				if subject_of(i) != &"":
					loader.place_cell(v, world.get_cell(v))

## Whether hall `hall`'s doors stand open (ExamDoor): while it is in session, a classroom's only to a
## wizard enrolled in its class (enrolled). With the wizard inside it, they shut behind them while its
## class is under way (a class started is sat until the bell rings it out) and stand open in passing
## time, or with no class there, so no one is shut in a classroom a bell has emptied (sneaking).
func hall_door_up (hall: int) -> bool:
	if world == null or hall < 0 or hall >= world.halls.size():
		return true
	var rec: LevelRecord = record()
	var open: bool = Timetable.in_session(world, hall, rec.rings)
	if world.halls[hall]["kind"] == &"lecture":
		if player != null and is_instance_valid(player) and Timetable.hall_inside(world, cell_at(player.global_position)) == hall:
			return rec.passing or not open
		return open and enrolled(hall)
	return open

## Whether the abominations keep still now: during a class (a period, not passing time).
func abominations_quiet () -> bool:
	return timetabled() and not record().passing

## How much sooner the abominations act up now, in passing time: 1, and SURGE_PER_RING more for every
## ring of the bell in the level.
func surge () -> float:
	return 1.0 + SURGE_PER_RING * float(record().rings) if timetabled() else 1.0

## The wizard cast the spell in slot `slot` (Abilities.cast): every scholar that sees it turns on them
## (Scholar.rouse), but for one that rang a bell as it struck.
func wizard_cast (_slot: StringName = &"damage") -> void:
	if not timetabled() or player == null or _rung_frame == Engine.get_physics_frames():
		return
	for node: Node in get_tree().get_nodes_in_group(&"scholar"):
		var s: Scholar = node as Scholar
		if s != null and not s.roused and s.sees(player):
			s.rouse()

## Whether the institute will teach `a` to the wizard: anything, but a big move (Relics.MOVES) only
## to a wizard who already has it, in its slot or as a paper (relics are how those are found).
func teaches (a: StringName) -> bool:
	return a != &"" and (not a in Relics.MOVES or Abilities.tier(player, a) > 0 or player.keyring.papers().any(func(code: int) -> bool: return KeyRing.paper_spell(code) == a))

## The classroom the wizard is in by right, or -1: one they went into enrolled in its class (or came
## back into through a department's way back) and have not left since. Tests seating the wizard in a
## classroom set it. And where they last were out of every classroom, to be put back to (keep_out;
## INF for nowhere yet).
var class_hall: int = -1
var _outside_at: Vector2 = Vector2.INF
## Whether the wizard is coming back through a department's way back (way_back_travel), to the portal
## in the classroom they left by: they are back in it by right.
var _from_department: bool = false

## Where the wizard is, by the timetable: going into a classroom they are enrolled in starts its class
## (passing time ends, the period begins, and its doors shut behind them, hall_door_up); getting into
## one they are not enrolled in any other way, they are put back out (keep_out). Staying in a
## classroom starts nothing, and a projection drifting through is let be until it ends.
func _watch_timetable () -> void:
	if not timetabled():
		return
	var rec: LevelRecord = record()
	var hall: int = Timetable.hall_inside(world, cell_at(player.global_position))
	if hall < 0 or world.halls[hall]["kind"] != &"lecture":
		class_hall = -1
		_outside_at = player.global_position
		return
	if hall == class_hall or player.phasing:
		return
	if not enrolled(hall):
		keep_out(hall)
		return
	class_hall = hall
	if rec.passing:
		rec.passing = false
		save_run()

## The wizard, got into classroom `hall` without being enrolled in its class (a warp, a rift, a
## projection ending there), put back where they last were out of the classrooms, or else on the step
## outside its first doorway.
func keep_out (hall: int) -> void:
	var to: Vector2 = _outside_at
	if not to.is_finite():
		var steps: Array = world.halls[hall]["steps"]
		to = cell_position(steps[0]) if not steps.is_empty() else player.global_position
	player.global_position = to
	player.velocity = Vector2.ZERO

## The master of hall `hall` standing in the level, or null.
func master_in (hall: int) -> Scholar:
	for node: Node in get_tree().get_nodes_in_group(&"master"):
		var m: Scholar = node as Scholar
		if m != null and m.hall == hall and not m.is_queued_for_deletion():
			return m
	return null

## Arriving through a department's portal (Department): at the way back it opens (WayBack), as a
## gate's traveller comes out of its partner.
const ARRIVE_WAY_BACK: int = -5

## Through a department's portal (Department) to level `to`, coming out of the way back that opens
## there (WayBack), near that level's way back, leading to the portal at `portal_cell` here. It
## lasts until it is used; using another department's portal moves it.
func department_travel (to: Vector2i, portal_cell: Vector2i) -> void:
	if travelling or run_ending > 0.0 or not Worlds.valid(to):
		return
	run.way_back = [to, Vector2.INF, coord, portal_cell]
	save_run()
	await _pass(Vector2(0, signf(float(to.y - coord.y))), to)
	_arrive(to, ARRIVE_WAY_BACK)

## Back through the way back (WayBack) to the department's portal it was opened from; it closes.
func way_back_travel () -> void:
	if travelling or run_ending > 0.0 or run.way_back.size() < 4:
		return
	var to: Vector2i = run.way_back[2]
	var portal_cell: Vector2i = run.way_back[3]
	run.way_back = []
	await _pass(Vector2(0, signf(float(to.y - coord.y))), to)
	arrival_pos = cell_position(portal_cell)
	_from_department = true
	_arrive(to, -3)

## A way back's prefab (loaded when first needed).
const WAY_BACK: String = "res://prefabs/way_back.tscn"
## How far (cells) from the way back the way back from a department stands: at least, and at most.
const WAY_BACK_NEAR: Vector2i = Vector2i(2, 8)
## How many cells of open air the way back from a department stands in, its own cell and those over it.
const WAY_BACK_AIR: int = 2

## The way back from a department (RunState.way_back), if it opened in this place: on the free floor
## nearest its way back, WAY_BACK_NEAR cells off, with open air over it as high as its arch
## (WAY_BACK_AIR cells, so nothing stands on top of it), found the first time, then kept. The
## wizard comes through the department's portal out of it (ARRIVE_WAY_BACK).
func _spawn_way_back () -> void:
	var back: Array = run.way_back
	if back.size() < 4 or back[0] != coord or map_elements == null or world == null:
		return
	if back[1] == Vector2.INF:
		var from: Vector2i = world.exits.get(Exit.BACK, Vector2i.ZERO)
		var fits: Callable = func(v: Vector2i) -> bool:
			if LevelGen.dist(v, from) < WAY_BACK_NEAR.x or LevelGen.dist(v, from) > WAY_BACK_NEAR.y:
				return false
			for k: int in range(1, WAY_BACK_AIR):
				if not world.is_valid(v + Vector2i(0, -k)) or world.get_cell(v + Vector2i(0, -k)).type != LevelGen.Type.EMPTY:
					return false
			return true
		var spot: Variant = LevelGen.best_of(world.free_floors(), func(v: Vector2i) -> int: return LevelGen.dist(v, from), fits)
		back[1] = cell_position(spot if spot != null else from)
	var node: WayBack = (load(WAY_BACK) as PackedScene).instantiate() as WayBack
	map_elements.add_child(node)
	node.global_position = back[1]
	node.setup(self)

# ------------------------------------------------------------------ lanterns

func light_lantern (lantern: Node) -> bool:
	if travelling or run_ending > 0.0 or not lantern.has_meta(&"cell") or is_lantern_spent(lantern):
		return false
	var was_vulnerable: bool = run.vulnerable
	snuffed = false
	_set_respawn(coord, lantern.get_meta(&"cell"))
	run.vulnerable = false
	_refresh_lanterns()
	# A lantern refills the hex's charges and mend's draughts.
	if player != null and player.has_node("Hex"):
		(player.get_node("Hex") as Hex).refill()
	if player != null and player.has_node("Mend"):
		(player.get_node("Mend") as Mend).refill()
	if was_vulnerable:
		RisoFx.burst(&"gain", (lantern as Node2D).global_position, Vector2.ZERO, [RisoPrint.EYE, RisoPrint.GLOW])
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
	RisoFx.burst(&"gain", at, Vector2.UP, [RisoPrint.NIGHT, RisoPrint.BLUE])
	return true

## Light a snuffed flame again (a dash).
func relight () -> void:
	if not snuffed:
		return
	snuffed = false
	if player != null and is_instance_valid(player):
		RisoFx.burst(&"gain", player.global_position + Vector2(0, -30), Vector2.ZERO, [RisoPrint.EYE, RisoPrint.GLOW])

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

## Touching the ghost returns its stars and relights the lantern its death burned out: lit again,
## it protects the next death, and, while the wizard has no other lantern lit, it is theirs again (as
## it was, their respawn). It does not heal (the wizard came back at full health).
func recover_ghost () -> void:
	if not run.has_ghost:
		return
	var stars: int = run.ghost_stars
	var at: Vector2 = run.ghost_pos
	var lantern: Array = run.ghost_lantern
	_clear_ghost()
	player.collect(stars)
	if lantern.size() == 2:
		run.record(lantern[0]).spent_lanterns.erase(lantern[1])
		if run.vulnerable and run.respawn_coord == lantern[0] and run.respawn_cell == lantern[1]:
			run.vulnerable = false
		_refresh_lanterns()
	RisoFx.burst(&"gain", at, Vector2.ZERO, [RisoPrint.GLOW, RisoPrint.ACCENT])
	save_run()

## The run is over: show the card, then start again at depth 0 of the run's seed with a fresh
## character and no records (the levels themselves are unchanged).
func end_run () -> void:
	if run_ending > 0.0:
		return
	RunState.delete_save()
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

func _spawn_ghost () -> void:
	if not run.has_ghost or run.ghost_coord != coord or map_elements == null or not is_instance_valid(map_elements):
		return
	if ghost_node != null and is_instance_valid(ghost_node):
		ghost_node.queue_free()
	ghost_node = GHOST.instantiate()
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
func save_run () -> void:
	if player == null or world == null or run_ending > 0.0:
		return
	RunState.write_save(run.to_save(coord, player.to_save()))

## Resume the saved run at its last lit lantern. False when there is nothing to continue.
func continue_run () -> bool:
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
		LevelGen.Type.EXAM_DOOR:
			return not bool(exam_doors.get(v, true))
		LevelGen.Type.GLYPH_SEAL:
			return not rec.opened.has(v)
	return false

func _physics_process (delta: float) -> void:
	since_bell += delta
	if world == null or travelling or player == null or not is_instance_valid(player):
		return
	gust_clock += delta
	var c: Vector2i = cell_at(player.global_position)
	if c != _last_seen_cell:
		_last_seen_cell = c
		reveal(c)
		# Stepping into a secret room's false wall (or drifting or warping into its rock) opens it.
		open_secret(secret_at(c))
	_watch_timetable()
	loader.sleep_far_chunks()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Debug-Back"):
		travel(Exit.BACK)
