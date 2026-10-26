extends Node2D
class_name PracticeTally
## The practice range's tally (PracticeRange), for debug runs: it stands unseen by the way in and
## keeps the range's foes for weighing the damage spells against one another.
## - Every foe in the range is taken in as it comes into the scene: it drops no stars and nothing is
##   noted of it (Wound.stars), and RESPAWN seconds after one laid with the range falls, it is back
##   where it was laid, whole.
## - Held `still` (the F7 panel's Practice range rows), the foes do nothing once they have landed
##   (SETTLE): they neither move nor attack (their touch still hurts), and drift back to their spots
##   after a blow knocks them aside.
##   Made `sturdy`, each has STURDY_HP rather than its depth's health (Wound.hp_for), to be struck
##   for a while.
## - At the top left of the screen it shows the spell in the damage slot and its tier, the foes'
##   health, and what the spell has done since it was taken up: the damage dealt in the last WINDOW
##   seconds, the most dealt in any WINDOW seconds, the damage all told, the casts, the foes slain
##   and how long they took on average from their first wound to their fall (every wound the foes
##   take is counted, the parry's that comes with every damage spell among them). Taking up another
##   spell (or another tier of it, or casting empowered) starts the count afresh, keeping the last
##   few results (HISTORY) under it to compare.
## Like the F7 panel's FPS counter it is plain text: a tool, not part of the print.

## Seconds a fallen foe takes to come back.
const RESPAWN: float = 3.0
## A sturdy foe's health.
const STURDY_HP: int = 20
## The span (seconds) of the running count of damage.
const WINDOW: float = 10.0
## How many earlier spells' results are kept on screen.
const HISTORY: int = 4
## How fast (px/s) a still foe drifts back to its spot after a blow.
const HOMING: float = 120.0
## Seconds a foe is left to land after it comes in, before it is held still (one held at once would
## hang in the middle of the cell it was laid in, above the floor), counted while it is awake (one
## far from the wizard sleeps with its chunk, LevelLoader.sleep_far_chunks, and does not fall).
const SETTLE: float = 0.4
## The tally's text: its canvas layer (over the print, under the F7 panel), where, how big, and
## how much closer than the font's own its lines are.
const LAYER: int = 2
const AT: Vector2 = Vector2(4, 4)
const FONT_SIZE: int = 6
const LINE_TIGHTEN: int = 2
## The parts of a foe that go on while it is held still: its art, its touch (and its stun), its
## health, its stunner and its shield.
const KEEP_GOING: Array[StringName] = [&"RisoArt", &"HitBox", &"Wound", &"Stunner", &"Shield"]

## Whether the range's foes are held still, and whether they are sturdy (see the class note). They
## last while the game runs, are not saved, and do nothing outside a debug run.
static var still: bool = false
static var sturdy: bool = false
## The tally of the range being played, or null.
static var instance: PracticeTally = null

var info: MapInfo
## The foes laid with the range that are standing, by the cell each was laid in.
var foes: Dictionary = {}
## The cells of those that have fallen, and when (on `clock`) each comes back.
var due: Dictionary = {}
## Foes come in while they are held still, and the seconds each has left to land (see SETTLE).
var landing: Dictionary = {}
## Seconds of game time since the tally came in: what the counts are timed by.
var clock: float = 0.0
## The spell being counted (its name and tier, and whether empowered), and what it has done since it
## was taken up: each wound (x when, y how much), the damage all told, the casts, the foes slain and
## the seconds each took from its first wound to its fall, all told; when each foe still standing
## was first wounded; and the most damage dealt in any WINDOW.
var spell: String = ""
var wounds: Array[Vector2] = []
var dealt: int = 0
var casts: int = 0
var slain: int = 0
var kill_time: float = 0.0
var first_wound: Dictionary = {}
var best: int = 0
## Earlier spells' results, the latest first.
var history: Array[String] = []
var label: Label
var _layer: CanvasLayer
var _player: Player


func setup(map_info: MapInfo, _v: Vector2i) -> void:
	info = map_info
	# It keeps no cell, so it never sleeps with its chunk (LevelLoader._sleeper): it keeps count
	# wherever in the range the wizard is.
	remove_meta(&"cell")


func _ready() -> void:
	# Always, so it can hide its text while the game is paused (see _process).
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	if info == null:
		info = MapInfo.instance
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	label = Label.new()
	label.position = AT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("line_spacing", -LINE_TIGHTEN)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(label)
	var elements: Node = get_parent()
	if elements != null:
		elements.child_entered_tree.connect(_arrived)
		for node: Node in elements.get_children():
			_arrived(node)


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _player != null and is_instance_valid(_player) and _player.visual_event.is_connected(_on_visual):
		_player.visual_event.disconnect(_on_visual)


## Something came into the level: taken in once it is set up (LevelLoader.place_cell sets it up
## after adding it).
func _arrived(node: Node) -> void:
	if node != self:
		_take_in.call_deferred(node)


## Take in `node` if it is a foe (it has a Wound): see the class note.
func _take_in(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or node.has_meta(&"practice_foe"):
		return
	var wound: Wound = node.get_node_or_null("Wound") as Wound
	if wound == null:
		return
	node.set_meta(&"practice_foe", true)
	wound.stars = false
	if sturdy and MapInfo.debug:
		wound.hp = STURDY_HP
	wound.hurt.connect(_on_hurt.bind(node))
	wound.slain.connect(_on_slain.bind(node))
	if node.has_meta(&"cell"):
		foes[node.get_meta(&"cell") as Vector2i] = node
	if still and MapInfo.debug:
		landing[node] = SETTLE


## Hold `foe` still where it stands, its spot from now on: what drives it stops (its own processing
## and its parts', but for KEEP_GOING).
static func hold(foe: Node) -> void:
	var body: Node2D = foe as Node2D
	if body != null:
		body.set_meta(&"practice_home", body.global_position)
	var parts: Array[Node] = [foe]
	parts.append_array(foe.get_children())
	for part: Node in parts:
		if StringName(part.name) in KEEP_GOING:
			continue
		part.set_process(false)
		part.set_physics_process(false)


func _on_hurt(damage: int, foe: Node) -> void:
	wounds.append(Vector2(clock, float(damage)))
	dealt += damage
	if not first_wound.has(foe):
		first_wound[foe] = clock


func _on_slain(foe: Node) -> void:
	slain += 1
	kill_time += clock - float(first_wound.get(foe, clock))
	first_wound.erase(foe)
	if foe.has_meta(&"cell"):
		var cell: Vector2i = foe.get_meta(&"cell")
		foes.erase(cell)
		due[cell] = clock + RESPAWN


func _on_visual(kind: StringName, _at: Vector2) -> void:
	if kind == &"cast":
		casts += 1


## Every foe laid with the range back where it was laid, afresh (as the F7 panel's rows change how
## they are): those standing are taken away first.
func respawn_all() -> void:
	for cell: Vector2i in foes:
		var foe: Node = foes[cell]
		if is_instance_valid(foe):
			foe.queue_free()
	foes.clear()
	due.clear()
	landing.clear()
	first_wound.clear()
	if info == null or info.world == null:
		return
	for v: Vector2i in info.world.objects:
		if Placeables.has_flag(info.world.get_cell(v).type, &"enemy"):
			_lay(v)


## Start counting afresh, for the same spell, forgetting earlier spells' results too.
func reset() -> void:
	spell = ""
	history.clear()
	_restart()


func _restart() -> void:
	wounds.clear()
	dealt = 0
	casts = 0
	slain = 0
	kill_time = 0.0
	best = 0
	first_wound.clear()


## Lay the foe of cell `v` again.
func _lay(v: Vector2i) -> void:
	if info != null and info.world != null and info.loader != null:
		info.loader.place_cell(v, info.world.get_cell(v))


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	clock += delta
	for cell: Vector2i in due.keys():
		if clock >= float(due[cell]):
			due.erase(cell)
			_lay(cell)
	for key: Variant in landing.keys():
		if not is_instance_valid(key) or (key as Node).is_queued_for_deletion():
			landing.erase(key)
			continue
		if (key as Node).can_process():
			landing[key] = float(landing[key]) - delta
		if float(landing[key]) <= 0.0:
			landing.erase(key)
			hold(key as Node)
	if still:
		for cell: Vector2i in foes:
			var foe: Node2D = foes[cell] as Node2D
			if foe != null and is_instance_valid(foe) and foe.has_meta(&"practice_home"):
				foe.global_position = foe.global_position.move_toward(foe.get_meta(&"practice_home") as Vector2, HOMING * delta)
	_follow()
	while not wounds.is_empty() and wounds[0].x <= clock - WINDOW:
		wounds.pop_front()
	best = maxi(best, recent())


## The damage dealt in the last WINDOW seconds.
func recent() -> int:
	var sum: float = 0.0
	for w: Vector2 in wounds:
		if w.x > clock - WINDOW:
			sum += w.y
	return roundi(sum)


## Keep up with the wizard: their spell (another starts the count afresh, see the class note), and
## their casts.
func _follow() -> void:
	var player: Player = info.player if info != null else null
	if player == null or not is_instance_valid(player):
		return
	if player != _player:
		_player = player
		if not player.visual_event.is_connected(_on_visual):
			player.visual_event.connect(_on_visual)
	var now: String = spell_name(player)
	if now == spell:
		return
	if spell != "" and (dealt > 0 or casts > 0):
		history.push_front(summary())
		history.resize(mini(history.size(), HISTORY))
	spell = now
	_restart()


## The spell in `player`'s damage slot, its tier and whether every cast is empowered (Empower.always).
static func spell_name(player: Player) -> String:
	var a: StringName = Abilities.spell(player)
	if a == &"":
		return "no damage spell"
	return "%s %s%s" % [Abilities.label(a), Abilities.roman(Abilities.tier(player, a)), " empowered" if Empower.always else ""]


## The foes' health as things stand.
func foe_hp() -> int:
	if sturdy:
		return STURDY_HP
	return Wound.hp_for(info.here.depth if info != null else 0)


## How long the foes slain took on average from their first wound to their fall (seconds), or -1
## with none slain.
func mean_kill() -> float:
	return kill_time / float(slain) if slain > 0 else -1.0


## This spell's results in a line, to keep when another is taken up.
func summary() -> String:
	var kill: String = "%.1f s" % mean_kill() if slain > 0 else "-"
	return "%s: best %d in %d s · kill %s · %d dmg, %d casts" % [spell, best, roundi(WINDOW), kill, dealt, casts]


func _process(_delta: float) -> void:
	_layer.visible = MapInfo.debug and not get_tree().paused
	if not _layer.visible:
		return
	var span: int = roundi(WINDOW)
	var lines: Array[String] = [
		"%s · foes %d hp%s%s" % [spell, foe_hp(), " · still" if still else "", " · sturdy" if sturdy else ""],
		"last %d s: %d dmg (%.1f/s) · best %d (%.1f/s)" % [span, recent(), float(recent()) / WINDOW, best, float(best) / WINDOW],
		"all: %d dmg · %d casts · %d slain · kill %s" % [dealt, casts, slain, "%.1f s" % mean_kill() if slain > 0 else "-"],
	]
	for line: String in history:
		lines.append(line)
	label.text = "\n".join(lines)
