extends Control
## The world atlas: the whole grid of places a run can travel, drawn at once, one tile a level, for
## looking over how things are spread across it rather than what any one level looks like (that
## is the generation lab's). Across, the world columns either side of the run's own (a run starts
## in the column of its seed); down, the rows of the band layout, the start in the middle. Each
## tile is coloured by its band, and over it, each a layer that can be turned off: the labyrinth's
## walls (the ways out a level does not have, Rules.maze_has), the key colour locking each side
## door (Rules.lateral_lock), relics (Relics.at, the move's letter, on grey when it waits behind a
## bone gate), skeleton keys (Rules.skeleton_at), bone vaults (Rules.bone_vault_at), hyperspace
## doors and where they come out (Worlds, SideWorld.destination), each boss in the column it is
## met in for this run (Bosses.column) and its gate row's sealed ways on, and how many levels each
## level is from the start, walking the labyrinth (with the bosses still alive, their gates
## sealed, or not).
##
## To the right of the grid, a bar for each row: the share of its levels holding the chosen thing,
## counted over many more columns than are drawn (CHART_COLUMNS), so it shows how the rules deal
## it rather than what this stretch happens to hold. The panel on the left sums up what is in view
## (the nearest relic, the steps to each boss) and can repeat that over many runs (RUNS), as the
## bosses' columns change from run to run. Hover over a tile to see what it holds; click to keep
## it shown. Drag to move about, the wheel to zoom.
##
## Nothing is laid out: everything here is the game's own rules of a place, worked out without
## collapsing a level, so it is instant and always agrees with the game (Rules.def_for).
## godot --path . res://tools/world_atlas/world_atlas.tscn   (or open the scene in the editor and press F6)

## The window the atlas opens in, when run on its own.
const WINDOW: Vector2i = Vector2i(1600, 900)
## The width of the panel of controls and sums on the left.
const PANEL_WIDTH: float = 340.0
## A tile's size in pixels at the start, and the least and most zoom allows.
const TILE: float = 18.0
const TILE_MIN: float = 5.0
const TILE_MAX: float = 64.0
## How much one turn of the wheel zooms.
const ZOOM_STEP: float = 1.15
## Tiles at least this big print their steps from the start and a relic's letter.
const TILE_TEXT: float = 22.0
## The margin round the grid, and the gap between it and the row chart.
const MARGIN: float = 24.0
const CHART_GAP: float = 16.0
## The row chart's width at most (a full bar), in pixels.
const CHART_WIDTH: float = 140.0
## How many world columns the row chart counts over, centred on the run's.
const CHART_COLUMNS: int = 600
## How many runs "Over many runs" works through (run seeds from the one shown on).
const RUNS: int = 200
## Rows drawn past the layout's ends (the outermost band goes on for ever).
const EXTRA_ROWS: int = 2
## A band's tile, by its archetype's name; one not listed is grey.
const BAND_COLORS: Dictionary = {
	&"garden": Color(0.36, 0.55, 0.36),
	&"cemetery": Color(0.42, 0.45, 0.55),
	&"institute": Color(0.5, 0.4, 0.6),
	&"crags": Color(0.6, 0.48, 0.36),
	&"sky": Color(0.45, 0.62, 0.78),
}
const OTHER_BAND: Color = Color(0.5, 0.5, 0.5)
## The key colours in order of rarity (Rules.KEY_RARITY), as the atlas draws them, and their names.
const KEY_COLORS: Array[Color] = [Color(1.0, 0.82, 0.2), Color(0.95, 0.42, 0.25), Color(0.45, 0.75, 0.35), Color(0.65, 0.35, 0.8)]
const KEY_NAMES: Array[String] = ["sun", "ember", "moss", "plum"]
## How the layers are drawn.
const WALL: Color = Color(0.08, 0.08, 0.1)
const RELIC: Color = Color(1.0, 0.85, 0.1)
const BONE: Color = Color(0.82, 0.8, 0.74)
const SKELETON: Color = Color(1.0, 1.0, 1.0)
const SIDE: Color = Color(0.75, 0.3, 1.0)
const BOSS: Color = Color(1.0, 0.1, 0.55)
const START: Color = Color(1.0, 1.0, 1.0)
const HOVER: Color = Color(1.0, 1.0, 1.0, 0.9)
const UNREACHED: Color = Color(0.0, 0.0, 0.0, 0.55)
const BACKGROUND: Color = Color(0.12, 0.12, 0.14)
const CHART_BAR: Color = Color(0.85, 0.75, 0.35)
## Each relic move's letter on its tile.
const MOVE_LETTERS: Dictionary = {&"double_jump": "J", &"wall_climb": "W", &"blink": "B", &"levitate": "L", &"astral": "A"}
## Bosses met anywhere along their gate row rather than in one column (the whale roams the sky's
## top row, WhaleHunt).
const ROAMING: Array[StringName] = [&"whale"]
## The layers that can be turned on and off: [its name, its box's text, what it shows].
const LAYERS: Array = [
	[&"walls", "Labyrinth walls", "A dark bar where a level has no way out (Rules.maze_has): the labyrinth's cut side doors and ways toward the start."],
	[&"locks", "Side door locks", "A tick inside each open side door in the key colour that locks it (Rules.lateral_lock): sun, ember, moss, plum."],
	[&"relics", "Relics", "A gold diamond where a relic lies (Relics.at), with its move's letter when zoomed in: J double jump, W wall climb, B blink, L levitate, A astral projection. On grey when it waits behind a bone gate."],
	[&"skeleton", "Skeleton keys", "A white bar where a secret room holds a skeleton key (Rules.skeleton_at)."],
	[&"bone", "Bone vaults", "A pale square where a bone vault of loot is laid (Rules.bone_vault_at)."],
	[&"side", "Hyperspace doors", "A violet dot where a level has a door into hyperspace (or another side world)."],
	[&"routes", "Hyperspace routes", "A violet line from each hyperspace door to the level it comes out in (SideWorld.destination). The level under the mouse always shows its own."],
	[&"bosses", "Bosses and gates", "A pink ring round the level each boss is met in for this run (Bosses.column), and a pink bar on every gate level's way on."],
	[&"steps", "Steps from the start", "Each level darkened by how many levels it is from the start, walking the labyrinth (and hyperspace), keys aside. Darkest are furthest; hatched are not reached within the columns drawn."],
	[&"sealed", "Gates sealed", "Count the steps with every boss alive: no way past a gate level's way on, nor through a hyperspace that leads past one."],
]
## Layers off when the atlas opens, as they crowd the grid when every level shows them (the level
## under the mouse shows its hyperspace route whatever this says).
const QUIET: Array[StringName] = [&"locks", &"routes"]
## Room kept right of the row chart's bars for their numbers.
const CHART_TEXT: float = 70.0

## What the row chart can count: [its name, its text].
const CHARTS: Array = [
	[&"relic", "Relics"], [&"skeleton", "Skeleton keys"], [&"bone", "Bone vaults"], [&"side", "Hyperspace doors"],
	[&"shut", "Ways out shut"], [&"steps", "Mean steps from the start"],
]
## A cell that is no tile.
const NONE: Vector2i = Vector2i(-999999, -999999)

## The run shown: its seed, which is also the column it starts in.
var run_seed: int = 28
## How many columns either side of the run's are drawn.
var span: int = 30
## Which layers are on, by name.
var layers: Dictionary = {}
## What the row chart counts.
var chart: StringName = &"relic"
## The rows drawn, top to bottom.
var rows: Array[int] = []
## What each place holds (info), kept while the layout stays the same.
var _infos: Dictionary = {}
## Each row's band name.
var _bands: Dictionary = {}
## Steps from the start to each place reached, for the run shown.
var steps: Dictionary = {}
## The row chart's numbers, by row: a share from 0 to 1 (or mean steps), and its text.
var _chart: Dictionary = {}
## The side worlds' kinds, to ask which levels deal their doors, and which is the tutorial's.
var _protos: Array[SideWorld] = []
var _hover: Vector2i = NONE
var _pinned: Vector2i = NONE
var _tile: float = TILE
var _offset: Vector2 = Vector2(MARGIN, MARGIN)
var _dragging: bool = false

var _map: Control
var _layout_pick: OptionButton
var _seed_box: SpinBox
var _span_box: SpinBox
var _chart_pick: OptionButton
var _sums: Label
var _runs: Label
var _detail: Label


func _ready() -> void:
	MapInfo.debug = false
	# The game draws at 320 x 180 and scales it up; a tool wants the window's own pixels.
	var win: Window = get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if win.mode == Window.MODE_WINDOWED and win.size.x < WINDOW.x:
		win.size = WINDOW
	for layer: Array in LAYERS:
		layers[layer[0]] = not layer[0] in QUIET
	_build_ui()
	_relayout()
	_fit.call_deferred()


# ------------------------------------------------------------------ the panel

func _build_ui() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	scroll.anchor_bottom = 1.0
	scroll.offset_right = PANEL_WIDTH
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH - 16, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	_title(box, "World atlas")
	var row: HBoxContainer = _row(box, "Band layout")
	_layout_pick = OptionButton.new()
	for layout_name: StringName in Bands.LAYOUTS:
		_layout_pick.add_item(String(layout_name))
		if layout_name == Bands.current:
			_layout_pick.select(_layout_pick.item_count - 1)
	_layout_pick.tooltip_text = "Which band layout to draw (Bands.LAYOUTS): the whole game, or the demo's garden."
	_layout_pick.item_selected.connect(func(i: int) -> void:
		Bands.use(StringName(_layout_pick.get_item_text(i)))
		_relayout())
	row.add_child(_layout_pick)
	_seed_box = _spin(box, "Run seed", 0, 99999, run_seed, "The run shown: its seed, and so the column it starts in. The bosses' columns are dealt by it.")
	_seed_box.value_changed.connect(func(v: float) -> void:
		run_seed = int(v)
		_recount()
		_centre())
	_span_box = _spin(box, "Columns either side", 2, 200, span, "How many world columns are drawn either side of the run's. Steps are only counted within them.")
	_span_box.value_changed.connect(func(v: float) -> void:
		span = int(v)
		_recount())
	_button(box, "Centre on the start", _centre, "Move the view back to the run's start.")
	_button(box, "Fit all in view", _fit, "Zoom so the whole grid and its row chart fit in the window.")

	_title(box, "Layers")
	for layer: Array in LAYERS:
		var check: CheckBox = CheckBox.new()
		check.text = layer[1]
		check.tooltip_text = layer[2]
		check.button_pressed = layers[layer[0]]
		var layer_name: StringName = layer[0]
		check.toggled.connect(func(on: bool) -> void:
			layers[layer_name] = on
			if layer_name == &"sealed":
				_recount()
			else:
				_map.queue_redraw())
		box.add_child(check)

	_title(box, "Row chart")
	_chart_pick = OptionButton.new()
	for c: Array in CHARTS:
		_chart_pick.add_item(c[1])
	_chart_pick.tooltip_text = "What the bars right of the grid count, row by row, over %d columns (steps only over the columns drawn)." % CHART_COLUMNS
	_chart_pick.item_selected.connect(func(i: int) -> void:
		chart = (CHARTS[i] as Array)[0]
		_count_chart()
		_map.queue_redraw())
	box.add_child(_chart_pick)

	_title(box, "In view")
	_sums = _note(box)
	_title(box, "Over many runs")
	_button(box, "Count over %d runs" % RUNS, _over_runs, "Steps from the start to each boss and to the nearest relic and skeleton key, for run seeds from the one shown on, as the bosses' columns change with the seed.")
	_runs = _note(box)
	_title(box, "The level under the mouse")
	_detail = _note(box)
	_title(box, "Key")
	_note(box).text = "Tile colour: its band. Dark bar: no way out there. Gold diamond: relic (grey behind it: behind a bone gate). White bar: skeleton key. Pale square: bone vault. Violet dot: hyperspace door. Pink ring: a boss, met there this run. Pink bar: a gate's sealed way on. White dot: the start. Darker: further from the start; hatched: not reached."

	_map = Control.new()
	_map.anchor_right = 1.0
	_map.anchor_bottom = 1.0
	_map.offset_left = PANEL_WIDTH
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_map_input)
	_map.mouse_exited.connect(func() -> void:
		_hover = NONE
		_show_detail()
		_map.queue_redraw())
	add_child(_map)


func _title(parent: Control, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)


func _row(parent: Control, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	parent.add_child(row)
	return row


func _spin(parent: Control, text: String, lo: float, hi: float, value: float, tip: String) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = 1
	spin.value = value
	spin.tooltip_text = tip
	_row(parent, text).add_child(spin)
	return spin


func _button(parent: Control, text: String, on: Callable, tip: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(on)
	parent.add_child(button)
	return button


func _note(parent: Control) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 24, 0)
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	return label


# ------------------------------------------------------------------ what each place holds

## The layout changed (or the atlas opened): forget what was worked out and lay the rows out again.
func _relayout() -> void:
	_infos.clear()
	_bands.clear()
	_protos.clear()
	for k: int in range(Worlds.KINDS.size()):
		_protos.append(Worlds.proto(k))
	var down: int = 0
	var up: int = 0
	for band: Dictionary in Bands.way(1):
		down += int(band["rows"])
	for band: Dictionary in Bands.way(-1):
		up += int(band["rows"])
	var g: int = Bands.garden_rows()
	rows.clear()
	for r: int in range(-(g + up + EXTRA_ROWS), g + down + EXTRA_ROWS + 1):
		rows.append(r)
		_bands[r] = NextWorldDef.archetype_at(r)
	_count_chart()
	_recount()
	_fit()


## What the place at `at` holds, worked out once: its band, its ways out and their locks, its
## relic, skeleton key, bone vault and side doors (each [kind, where it comes out or NONE for a dead
## end, whether that level's way back leads in again]), and its gate.
func info(at: Vector2i) -> Dictionary:
	if _infos.has(at):
		return _infos[at]
	var open: Dictionary = {}
	for exit: int in [MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK]:
		open[exit] = Rules.maze_has(at, exit)
	var relic: StringName = Relics.at(at)
	var doors: Array = []
	for k: int in range(_protos.size()):
		if _protos[k] is Tutorial or not _protos[k].deals(at):
			continue
		var side: SideWorld = Worlds.def_for(Worlds.side_at(k, at)) as SideWorld
		var out: Vector2i = NONE if side.dead_end() else side.destination()
		var back: bool = out != NONE and Worlds.arriving_at(out) == Worlds.side_at(k, at)
		doors.append([k, out, back])
	var got: Dictionary = {
		"open": open,
		"locks": [Rules.lateral_lock(at, MapInfo.Exit.LEFT), Rules.lateral_lock(at, MapInfo.Exit.RIGHT)],
		"relic": relic,
		"gated": relic != &"" and Rules.relic_gated_at(at),
		"skeleton": Rules.skeleton_at(at),
		"bone": Rules.bone_vault_at(at),
		"doors": doors,
		"gate": Bosses.gate_at(at.y),
	}
	_infos[at] = got
	return got


## The columns drawn, left to right.
func columns() -> Array[int]:
	var out: Array[int] = []
	for x: int in range(run_seed - span, run_seed + span + 1):
		out.append(x)
	return out


## Where each boss of the layout is met in the run of seed `run_at`: its level, by name (a roaming one's
## column is the run's own, for the steps: it comes along its row).
func boss_places(run_at: int) -> Dictionary:
	var out: Dictionary = {}
	for boss: StringName in Bands.bosses():
		var row: int = Bosses.row_of(boss)
		if row == 0:
			continue
		out[boss] = Vector2i(run_at if boss in ROAMING else Bosses.column(boss, run_at), row)
	return out


## Steps from the start of the run of seed `run_at` to every place reached within `span` columns of it, walking
## the labyrinth's ways out (and hyperspace, two steps: in and out), keys and prices aside. With
## `sealed`, no way leads out past a gate (every boss alive).
func steps_from(run_at: int, sealed: bool) -> Dictionary:
	var lo: int = run_at - span
	var hi: int = run_at + span
	var first: int = rows[0]
	var last: int = rows[-1]
	var out: Dictionary = {}
	var start: Vector2i = Vector2i(run_at, 0)
	var buckets: Array = [[start]]
	out[start] = 0
	var d: int = 0
	while d < buckets.size():
		var bucket: Array = buckets[d]
		var i: int = 0
		while i < bucket.size():
			var at: Vector2i = bucket[i]
			i += 1
			if int(out[at]) != d:
				continue
			for next: Array in _ways(at, sealed):
				var to: Vector2i = next[0]
				if to.x < lo or to.x > hi or to.y < first or to.y > last:
					continue
				var cost: int = d + int(next[1])
				if out.has(to) and int(out[to]) <= cost:
					continue
				out[to] = cost
				while buckets.size() <= cost:
					buckets.append([])
				(buckets[cost] as Array).append(to)
		d += 1
	return out


## The places a step (or two, through hyperspace) from `at`: [where, steps].
func _ways(at: Vector2i, sealed: bool) -> Array:
	var got: Dictionary = info(at)
	var open: Dictionary = got["open"]
	var on: int = NextWorldDef.away(at.y)
	var out: Array = []
	if open[MapInfo.Exit.LEFT]:
		out.append([at + Vector2i.LEFT, 1])
	if open[MapInfo.Exit.RIGHT]:
		out.append([at + Vector2i.RIGHT, 1])
	if open[MapInfo.Exit.DEEPER] and not (sealed and got["gate"] != &""):
		out.append([Vector2i(at.x, at.y + on), 1])
	if open[MapInfo.Exit.BACK]:
		var home: Vector2i = Vector2i(at.x, -1 if at.y == 0 else at.y - on)
		# The way back from the row past a gate is the gate's sealed way on, seen from the far side.
		if not (sealed and Bosses.gate_at(home.y) != &"" and absi(home.y) < absi(at.y)):
			out.append([home, 1])
	for door: Array in got["doors"]:
		var to: Vector2i = door[1]
		if to != NONE and not (sealed and not Bosses.crossed(at.y, to.y).is_empty()):
			out.append([to, 2])
	# Coming out of hyperspace into `at`, its way back leads in and back out where it was entered.
	var from: Variant = Worlds.arriving_at(at)
	if from != null:
		var origin: Vector2i = Worlds.origin_of(from)
		if not (sealed and not Bosses.crossed(origin.y, at.y).is_empty()):
			out.append([origin, 2])
	return out


# ------------------------------------------------------------------ the sums

## Count the steps and the sums for the run shown, and draw it again.
func _recount() -> void:
	steps = steps_from(run_seed, bool(layers.get(&"sealed", true)))
	if chart == &"steps":
		_count_chart()
	_sum_view()
	_map.queue_redraw()


## The row chart's numbers for what it counts (see CHARTS), row by row.
func _count_chart() -> void:
	_chart.clear()
	@warning_ignore("integer_division")
	var from: int = run_seed - CHART_COLUMNS / 2
	for r: int in rows:
		if chart == &"steps":
			var total: int = 0
			var n: int = 0
			for x: int in columns():
				if steps.has(Vector2i(x, r)):
					total += int(steps[Vector2i(x, r)])
					n += 1
			_chart[r] = [float(total) / float(n) if n > 0 else 0.0, "%.1f" % (float(total) / float(n)) if n > 0 else "-"]
			continue
		var hits: float = 0.0
		for x: int in range(from, from + CHART_COLUMNS):
			hits += _chart_value(Vector2i(x, r))
		var share: float = hits / float(CHART_COLUMNS)
		_chart[r] = [share, "%.0f%%" % (100.0 * share)]


## How much level `at` counts toward the chart (1 for one that holds it; a share for ways shut).
## Asked of the rules directly rather than info, as it runs over many more columns than are drawn.
func _chart_value(at: Vector2i) -> float:
	match chart:
		&"relic":
			return 1.0 if Relics.at(at) != &"" else 0.0
		&"skeleton":
			return 1.0 if Rules.skeleton_at(at) else 0.0
		&"bone":
			return 1.0 if Rules.bone_vault_at(at) else 0.0
		&"side":
			for p: SideWorld in _protos:
				if not p is Tutorial and p.deals(at):
					return 1.0
			return 0.0
		&"shut":
			var shut: int = 0
			for exit: int in [MapInfo.Exit.LEFT, MapInfo.Exit.RIGHT, MapInfo.Exit.DEEPER, MapInfo.Exit.BACK]:
				if not Rules.maze_has(at, exit):
					shut += 1
			return float(shut) / 4.0
	return 0.0


## The panel's sums of what is in view.
func _sum_view() -> void:
	var levels: int = 0
	var reached: int = 0
	var relics: Dictionary = {}
	var relic_count: int = 0
	var gated: int = 0
	var skeletons: int = 0
	var bones: int = 0
	var sides: int = 0
	var dead: int = 0
	var nearest_relic: Array = [-1, NONE]
	var nearest_key: Array = [-1, NONE]
	for r: int in rows:
		for x: int in columns():
			var at: Vector2i = Vector2i(x, r)
			var got: Dictionary = info(at)
			levels += 1
			var s: int = int(steps.get(at, -1))
			if s >= 0:
				reached += 1
			var relic: StringName = got["relic"]
			if relic != &"":
				relic_count += 1
				relics[relic] = int(relics.get(relic, 0)) + 1
				if got["gated"]:
					gated += 1
				if s >= 0 and (int(nearest_relic[0]) < 0 or s < int(nearest_relic[0])):
					nearest_relic = [s, at]
			if got["skeleton"]:
				skeletons += 1
				if s >= 0 and (int(nearest_key[0]) < 0 or s < int(nearest_key[0])):
					nearest_key = [s, at]
			if got["bone"]:
				bones += 1
			for door: Array in got["doors"]:
				sides += 1
				if door[1] == NONE:
					dead += 1
	var lines: Array[String] = []
	lines.append("%d levels drawn (%d columns by %d rows); %d reached from the start%s." % [levels, columns().size(), rows.size(), reached,
			" with every gate sealed" if layers.get(&"sealed", true) else ""])
	var moves: Array[String] = []
	for move: StringName in Relics.MOVES:
		moves.append("%s %d" % [MOVE_LETTERS.get(move, "?"), int(relics.get(move, 0))])
	lines.append("Relics: %d (%.1f%% of levels; %s); %d behind bone gates." % [relic_count, 100.0 * relic_count / maxf(1, levels), ", ".join(moves), gated])
	lines.append("Nearest relic: %s." % _steps_text(nearest_relic))
	lines.append("Skeleton keys: %d (%.1f%%); nearest: %s." % [skeletons, 100.0 * skeletons / maxf(1, levels), _steps_text(nearest_key)])
	lines.append("Bone vaults: %d (%.1f%%)." % [bones, 100.0 * bones / maxf(1, levels)])
	lines.append("Hyperspace doors: %d (%.1f%%), %d of them dead ends." % [sides, 100.0 * sides / maxf(1, levels), dead])
	var places: Dictionary = boss_places(run_seed)
	for boss: StringName in places:
		var at: Vector2i = places[boss]
		var s: int = int(steps.get(at, -1))
		lines.append("%s: world %d, row %d%s; %s." % [String(boss).capitalize(), at.x, at.y, " (roams its row)" if boss in ROAMING else "",
				("%d steps from the start" % s) if s >= 0 else "not reached in view"])
	_sums.text = "\n".join(lines)


func _steps_text(found: Array) -> String:
	if int(found[0]) < 0:
		return "none reached in view"
	var at: Vector2i = found[1]
	return "%d steps (world %d, row %d)" % [int(found[0]), at.x, at.y]


## Steps to each boss and to the nearest relic and skeleton key, over RUNS runs from the one shown.
func _over_runs() -> void:
	_runs.text = summarize_runs(run_seed, RUNS, bool(layers.get(&"sealed", true)))


## The sums over `count` runs from seed `first` (see _over_runs), as text.
func summarize_runs(first: int, count: int, sealed: bool) -> String:
	var to_boss: Dictionary = {}
	var to_relic: Array[int] = []
	var to_key: Array[int] = []
	var no_relic: int = 0
	for run_at: int in range(first, first + count):
		var s: Dictionary = steps_from(run_at, sealed)
		var places: Dictionary = boss_places(run_at)
		for boss: StringName in places:
			if s.has(places[boss]):
				if not to_boss.has(boss):
					to_boss[boss] = []
				(to_boss[boss] as Array).append(int(s[places[boss]]))
		var best_relic: int = -1
		var best_key: int = -1
		for at: Vector2i in s:
			var got: Dictionary = info(at)
			var n: int = int(s[at])
			if got["relic"] != &"" and (best_relic < 0 or n < best_relic):
				best_relic = n
			if got["skeleton"] and (best_key < 0 or n < best_key):
				best_key = n
		if best_relic >= 0:
			to_relic.append(best_relic)
		else:
			no_relic += 1
		if best_key >= 0:
			to_key.append(best_key)
	var lines: Array[String] = ["Over %d runs (seeds %d to %d), steps from the start%s:" % [count, first, first + count - 1, ", gates sealed" if sealed else ""]]
	for boss: StringName in Bands.bosses():
		if to_boss.has(boss):
			lines.append("%s: %s." % [String(boss).capitalize(), _spread(to_boss[boss], count)])
	lines.append("Nearest relic: %s%s." % [_spread(to_relic, count), "; none reached in %d" % no_relic if no_relic > 0 else ""])
	lines.append("Nearest skeleton key: %s." % _spread(to_key, count))
	return "\n".join(lines)


## A list of steps summed up: its least, quartiles, most and mean (and how many of `count` it holds).
func _spread(values: Array, count: int) -> String:
	if values.is_empty():
		return "never reached"
	var sorted: Array[int] = []
	sorted.assign(values)
	sorted.sort()
	var total: int = 0
	for v: int in sorted:
		total += v
	var at: Callable = func(q: float) -> int: return sorted[mini(int(q * sorted.size()), sorted.size() - 1)]
	var text: String = "mean %.1f, least %d, quartiles %d / %d / %d, most %d" % [float(total) / sorted.size(), sorted[0], at.call(0.25), at.call(0.5), at.call(0.75), sorted[-1]]
	if sorted.size() < count:
		text += " (reached in %d of %d)" % [sorted.size(), count]
	return text


# ------------------------------------------------------------------ the map

## The top-left corner of the tile at `at`, in the map's own pixels.
func tile_at(at: Vector2i) -> Vector2:
	return _offset + Vector2((at.x - (run_seed - span)) * _tile, rows.find(at.y) * _tile)


## The place under the map's pixel `p`, or NONE.
func place_at(p: Vector2) -> Vector2i:
	var cell: Vector2 = ((p - _offset) / _tile).floor()
	var c: int = int(cell.x)
	var r: int = int(cell.y)
	if c < 0 or c > span * 2 or r < 0 or r >= rows.size():
		return NONE
	return Vector2i(run_seed - span + c, rows[r])


## Move the view so the start is in the middle.
func _centre() -> void:
	if _map == null:
		return
	var room: Vector2 = _map.size if _map.size.x > 0 else Vector2(WINDOW) - Vector2(PANEL_WIDTH, 0)
	var start: Vector2 = Vector2(span * _tile, rows.find(0) * _tile) + Vector2(_tile, _tile) * 0.5
	_offset = room * 0.5 - start
	_map.queue_redraw()


## Zoom so the whole grid and its row chart fit in the map, and put them in its middle.
func _fit() -> void:
	if _map == null:
		return
	var room: Vector2 = _map.size if _map.size.x > 0 else Vector2(WINDOW) - Vector2(PANEL_WIDTH, 0)
	var across: float = room.x - 2.0 * MARGIN - CHART_GAP - CHART_WIDTH - CHART_TEXT
	var down: float = room.y - 2.0 * MARGIN - 20.0
	_tile = clampf(floorf(minf(across / float(span * 2 + 1), down / float(rows.size()))), TILE_MIN, TILE_MAX)
	var whole: Vector2 = Vector2((span * 2 + 1) * _tile + CHART_GAP + CHART_WIDTH + CHART_TEXT, rows.size() * _tile)
	_offset = ((room - whole) * 0.5).floor() + Vector2(0, 10)
	_map.queue_redraw()


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				var was: float = _tile
				_tile = clampf(_tile * (ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP), TILE_MIN, TILE_MAX)
				_offset = button.position - (button.position - _offset) * (_tile / was)
				_map.queue_redraw()
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_dragging = true
				_pinned = NONE if place_at(button.position) == _pinned else place_at(button.position)
				_show_detail()
				_map.queue_redraw()
			else:
				_dragging = false
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _dragging and motion.button_mask != 0:
			_offset += motion.relative
		var at: Vector2i = place_at(motion.position)
		if at != _hover:
			_hover = at
			_show_detail()
		_map.queue_redraw()


func _draw_map() -> void:
	var font: Font = ThemeDB.fallback_font
	var t: float = _tile
	var view: Rect2 = Rect2(Vector2.ZERO, _map.size)
	var furthest: int = 1
	for at: Vector2i in steps:
		furthest = maxi(furthest, int(steps[at]))
	var places: Dictionary = boss_places(run_seed)
	var cols: Array[int] = columns()
	# The tiles, then what lies in them.
	for r: int in rows:
		for x: int in cols:
			var at: Vector2i = Vector2i(x, r)
			var p: Vector2 = tile_at(at)
			var rect: Rect2 = Rect2(p, Vector2(t, t))
			if not view.intersects(rect):
				continue
			var got: Dictionary = info(at)
			_map.draw_rect(rect.grow(-0.5), BAND_COLORS.get(_bands[r], OTHER_BAND))
			if layers[&"steps"]:
				if steps.has(at):
					_map.draw_rect(rect.grow(-0.5), Color(0, 0, 0, 0.7 * float(steps[at]) / float(furthest)))
				else:
					_map.draw_rect(rect.grow(-0.5), UNREACHED)
					_map.draw_line(p + Vector2(2, t - 2), p + Vector2(t - 2, 2), Color(1, 1, 1, 0.25), 1.0)
			_draw_marks(at, got, p, font)
	# Walls and gates over the tiles, so they read across tile edges.
	for r: int in rows:
		for x: int in cols:
			var at: Vector2i = Vector2i(x, r)
			var p: Vector2 = tile_at(at)
			if not view.intersects(Rect2(p, Vector2(t, t)).grow(t)):
				continue
			var got: Dictionary = info(at)
			var open: Dictionary = got["open"]
			var w: float = maxf(2.0, t * 0.16)
			if layers[&"walls"]:
				if not open[MapInfo.Exit.RIGHT]:
					_map.draw_rect(Rect2(p + Vector2(t - w * 0.5, 0), Vector2(w, t)), WALL)
				if x == cols[0] and not open[MapInfo.Exit.LEFT]:
					_map.draw_rect(Rect2(p + Vector2(-w * 0.5, 0), Vector2(w, t)), WALL)
				if r != 0 and not open[MapInfo.Exit.BACK]:
					var y: float = 0.0 if r > 0 else t
					_map.draw_rect(Rect2(p + Vector2(0, y - w * 0.5), Vector2(t, w)), WALL)
			if layers[&"bosses"] and got["gate"] != &"":
				var y2: float = t if r > 0 else 0.0
				_map.draw_rect(Rect2(p + Vector2(t * 0.15, y2 - w * 0.5), Vector2(t * 0.7, w)), BOSS)
	var routed: Array[Vector2i] = []
	if layers[&"routes"]:
		for r: int in rows:
			for x: int in cols:
				routed.append(Vector2i(x, r))
	for at: Vector2i in [_hover, _pinned]:
		if at != NONE:
			routed.append(at)
	for at: Vector2i in routed:
		var bold: bool = at == _hover or at == _pinned
		for door: Array in info(at)["doors"]:
			var to: Vector2i = door[1]
			if to == NONE or rows.find(to.y) < 0:
				continue
			var half: Vector2 = Vector2(t, t) * 0.5
			_map.draw_line(tile_at(at) + half, tile_at(to) + half, SIDE if bold else Color(SIDE, 0.7), maxf(2.5 if bold else 1.0, t * 0.08), true)
	if layers[&"bosses"]:
		for boss: StringName in places:
			var at: Vector2i = places[boss]
			if boss in ROAMING:
				var left: Vector2 = tile_at(Vector2i(cols[0], at.y))
				_map.draw_rect(Rect2(left, Vector2(t * cols.size(), t)), Color(BOSS, 0.8), false, maxf(1.5, t * 0.1))
			else:
				_map.draw_arc(tile_at(at) + Vector2(t, t) * 0.5, t * 0.62, 0.0, TAU, 32, BOSS, maxf(2.0, t * 0.14), true)
			var label: String = String(boss).capitalize()
			var where: Vector2 = tile_at(at) + Vector2(t * 1.2, t * 0.5 + 5)
			var wide: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			_map.draw_rect(Rect2(where + Vector2(-3, -wide.y + 2), wide + Vector2(6, 2)), Color(BACKGROUND, 0.85))
			_map.draw_string(font, where, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BOSS)
	# The start.
	var start: Vector2 = tile_at(Vector2i(run_seed, 0)) + Vector2(t, t) * 0.5
	_map.draw_circle(start, t * 0.3, START)
	_map.draw_circle(start, t * 0.14, WALL)
	for at: Vector2i in [_hover, _pinned]:
		if at != NONE:
			_map.draw_rect(Rect2(tile_at(at), Vector2(t, t)), HOVER, false, 2.0)
	_draw_chart(font)


## What lies in the tile at `at`, by the layers that are on.
func _draw_marks(at: Vector2i, got: Dictionary, p: Vector2, font: Font) -> void:
	var t: float = _tile
	if layers[&"locks"]:
		var locks: Array = got["locks"]
		var open: Dictionary = got["open"]
		var tick: Vector2 = Vector2(maxf(1.5, t * 0.1), t * 0.3)
		if open[MapInfo.Exit.LEFT]:
			_map.draw_rect(Rect2(p + Vector2(1, t * 0.35), tick), KEY_COLORS[int(locks[0])])
		if open[MapInfo.Exit.RIGHT]:
			_map.draw_rect(Rect2(p + Vector2(t - 1 - tick.x, t * 0.35), tick), KEY_COLORS[int(locks[1])])
	if layers[&"relics"] and got["relic"] != &"":
		var c: Vector2 = p + Vector2(t * 0.38, t * 0.38)
		var r: float = t * 0.26
		if got["gated"]:
			_map.draw_rect(Rect2(c - Vector2(r, r) * 1.1, Vector2(r, r) * 2.2), BONE)
		_map.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), RELIC)
		if t >= TILE_TEXT:
			_map.draw_string(font, c + Vector2(-r * 0.6, r * 0.55), MOVE_LETTERS.get(got["relic"], "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(t * 0.32), WALL)
	if layers[&"skeleton"] and got["skeleton"]:
		_map.draw_rect(Rect2(p + Vector2(t * 0.14, t * 0.76), Vector2(t * 0.36, t * 0.1)), SKELETON)
	if layers[&"bone"] and got["bone"]:
		_map.draw_rect(Rect2(p + Vector2(t * 0.66, t * 0.44), Vector2(t * 0.2, t * 0.2)), BONE)
	if layers[&"side"] and not (got["doors"] as Array).is_empty():
		_map.draw_circle(p + Vector2(t * 0.74, t * 0.26), t * 0.13, SIDE)
	if layers[&"steps"] and t >= TILE_TEXT and steps.has(at):
		_map.draw_string(font, p + Vector2(t * 0.55, t * 0.92), str(steps[at]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(t * 0.3), Color(1, 1, 1, 0.8))


## The bars right of the grid: one a row, for what the chart counts.
func _draw_chart(font: Font) -> void:
	var t: float = _tile
	var left: float = tile_at(Vector2i(run_seed + span, 0)).x + t + CHART_GAP
	var most: float = 0.0
	for r: int in rows:
		most = maxf(most, float((_chart.get(r, [0.0, ""]) as Array)[0]))
	if most <= 0.0:
		most = 1.0
	var top: float = tile_at(Vector2i(run_seed, rows[0])).y
	_map.draw_string(font, Vector2(left, top - 6), "%s, by row" % (CHARTS[_chart_pick.selected] as Array)[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	for r: int in rows:
		var bar: Array = _chart.get(r, [0.0, ""])
		var y: float = tile_at(Vector2i(run_seed, r)).y
		var w: float = CHART_WIDTH * float(bar[0]) / most
		_map.draw_rect(Rect2(Vector2(left, y + t * 0.15), Vector2(w, t * 0.7)), CHART_BAR)
		_map.draw_string(font, Vector2(left + w + 4, y + t * 0.75), "%d: %s" % [r, bar[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(t * 0.6, 9, 13)), Color(1, 1, 1, 0.7))


# ------------------------------------------------------------------ the level under the mouse

func _show_detail() -> void:
	var at: Vector2i = _pinned if _pinned != NONE else _hover
	if at == NONE:
		_detail.text = "Hover over a level (click to keep it)."
		return
	_detail.text = describe(at)


## What level `at` holds, as lines of text.
func describe(at: Vector2i) -> String:
	var got: Dictionary = info(at)
	var lines: Array[String] = ["%s (%s)" % [Rules.where(at), String(_bands.get(at.y, NextWorldDef.archetype_at(at.y)))]]
	lines.append("World %d, row %d; %s." % [at.x, at.y, ("%d steps from the start" % int(steps[at])) if steps.has(at) else "not reached in view"])
	var open: Dictionary = got["open"]
	var locks: Array = got["locks"]
	var ways: Array[String] = []
	ways.append("left (%s lock)" % KEY_NAMES[int(locks[0])] if open[MapInfo.Exit.LEFT] else "no left")
	ways.append("right (%s lock)" % KEY_NAMES[int(locks[1])] if open[MapInfo.Exit.RIGHT] else "no right")
	ways.append("on" if open[MapInfo.Exit.DEEPER] else "no way on")
	ways.append("back" if open[MapInfo.Exit.BACK] else "no way back")
	lines.append("Ways out: %s." % ", ".join(ways))
	if got["relic"] != &"":
		lines.append("Relic: %s%s." % [String(got["relic"]).capitalize(), ", behind a bone gate" if got["gated"] else ""])
	if got["skeleton"]:
		lines.append("A skeleton key in a secret room.")
	if got["bone"]:
		lines.append("A bone vault.")
	for door: Array in got["doors"]:
		var to: Vector2i = door[1]
		var kind_name: String = _protos[int(door[0])].name
		lines.append("A door into %s: %s." % [kind_name, "a dead end" if to == NONE else "out at world %d, row %d%s" % [to.x, to.y, "" if door[2] else " (another's way back there)"]])
	var from: Variant = Worlds.arriving_at(at)
	if from != null:
		var origin: Vector2i = Worlds.origin_of(from)
		lines.append("Its way back leads into hyperspace, from world %d, row %d." % [origin.x, origin.y])
	if got["gate"] != &"":
		var places: Dictionary = boss_places(run_seed)
		var here: bool = places.get(got["gate"], NONE) == at
		lines.append("A gate level of the %s%s." % [String(got["gate"]).capitalize(), ", met here this run" if here else ""])
	return "\n".join(lines)
