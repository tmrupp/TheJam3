class_name Abilities
## Tiered abilities, learned at shrines (there is no shop), except that tier I of the big moves
## (double jump, wall climb, blink, levitate, astral projection) only comes from a relic (see
## Relics). Tier 0 is not owned; a run starts knowing the dash, slash and mend (tier 1). Each tier
## improves the ability. Tiers live on the player and reset when a run ends.
## - Three slots (SLOTS), each holding one ability at a time on a button of its own (ACTIONS);
##   learning another for a slot replaces the one in it:
##   - damage, on the Spell button (Q, or the pad's X): hex (a bolt), slash (an arc in front),
##     nova (a burst all round), push (a gust that shoves), seeker (a homing bolt) and lunge (a
##     stab that throws the wizard forward). The wizard's only ways to hurt; the
##     dash no longer strikes (DashStrike only tears webs and cuts threads). Whichever is held, the
##     button also raises the parry guard (Parry, not a spell of its own: its base effect, on its
##     own cooldown), so every damage spell parries.
##   - movement, on the Dash button (Shift, or the right trigger): the dash, blink, astral
##     projection, levitate, rift (open your own teleporters), warp (to a random floor) and ferry
##     (a gliding raft, see Ferry). The dash and blink are the wizard's own moves (Player); the
##     rest are cast.
##   - utility, on the Utility button (R, or the right shoulder button): awareness and mend (heal to
##     full from draughts a lantern refills, see Mend). A utility spell never moves the wizard or
##     hurts anything itself; it may make the other two slots' spells better.
##   Warp and rift cost stars each cast (cast_price).
## - Perks stack: double jump, wall climb, vigor (max health), speed (run speed), keyring (carry
##   more keys, see KeyRing) and ward (a ring of plates that takes a hit and grows back, see Ward).
##
## Every ability is one entry in ABILITIES. What a tier does lives with whatever does the ability:
## a node on the wizard (its `set_tier`, and `cast_spell` for a spell), or, for the wizard's own
## moves (the dash, double jump, wall climb, speed, vigor), Player.tune_moves. A new ability is an
## entry here, its node (or a line in tune_moves), and its mark (RisoGlyph).

## Every ability, in the order shrines go round them (see offers):
## - "max": its top tier; "base": the tier a run starts with (0 when not given);
## - "slot": the slot it takes (SLOTS), for one that takes a slot; "cast": false for the wizard's
##   own moves in the movement slot (the dash, blink), which are not cast; "cost": stars a cast at
##   depth 0 (see cast_price), for a spell that costs any;
## - "node": the wizard's child that does it, told its tier by `set_tier(n)` (and, when a spell,
##   cast by `cast_spell() -> bool`, asked how ready it is by `readiness() -> float` and how long it
##   has left by `running() -> Vector2`, for the spell orb). With "make" (the path of its script, or of its scene)
##   it exists only while the ability is known (or always, with "always"); without, it is part of
##   the wizard's scene.
const ABILITIES: Dictionary = {
	&"dash": {"max": 4, "base": 1, "slot": &"move", "cast": false},
	&"double_jump": {"max": 3},
	&"wall_climb": {"max": 3},
	&"blink": {"max": 3, "slot": &"move", "cast": false, "node": "Blink", "make": "res://prefabs/upgrades/Blink.tscn"},
	&"astral": {"max": 4, "slot": &"move", "node": "AstralProjection"},
	&"hex": {"max": 4, "slot": &"damage", "node": "Hex", "make": "res://scripts/Hex.gd"},
	&"slash": {"max": 4, "base": 1, "slot": &"damage", "node": "Slash", "make": "res://scripts/Slash.gd"},
	&"nova": {"max": 4, "slot": &"damage", "node": "Nova", "make": "res://scripts/Nova.gd"},
	&"push": {"max": 4, "slot": &"damage", "node": "Push", "make": "res://scripts/Push.gd"},
	&"seeker": {"max": 4, "slot": &"damage", "node": "Seeker", "make": "res://scripts/Seeker.gd"},
	&"lunge": {"max": 4, "slot": &"damage", "node": "Lunge", "make": "res://scripts/Lunge.gd"},
	&"levitate": {"max": 3, "slot": &"move", "node": "Levitate", "make": "res://scripts/Levitate.gd"},
	&"awareness": {"max": 3, "slot": &"utility", "node": "Awareness", "make": "res://scripts/Awareness.gd"},
	&"rift": {"max": 3, "slot": &"move", "cost": 2.0, "node": "Rift", "make": "res://scripts/Rift.gd"},
	&"vigor": {"max": 3},
	&"speed": {"max": 3},
	&"warp": {"max": 3, "slot": &"move", "cost": 4.0, "node": "Warp", "make": "res://scripts/Warp.gd"},
	&"mend": {"max": 3, "base": 1, "slot": &"utility", "node": "Mend", "make": "res://scripts/Mend.gd"},
	&"keyring": {"max": 3},
	&"ferry": {"max": 3, "slot": &"move", "node": "Ferry", "make": "res://scripts/Ferry.gd"},
	&"ward": {"max": 3, "node": "Ward", "make": "res://scripts/Ward.gd"},
}
## The slots: the damage spell's (the Spell button), the movement's (Dash) and the utility spell's
## (Utility).
const SLOTS: Array[StringName] = [&"damage", &"move", &"utility"]
## Run speed added per tier of speed, as a fraction of the base.
const SPEED_PER_TIER: float = 0.15
const BASE_HEALTH: int = 3
const SPELL_ACTION: StringName = &"Spell"
const UTILITY_ACTION: StringName = &"Utility"


## Every ability, in order (see ABILITIES).
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a: StringName in ABILITIES:
		out.append(a)
	return out


## The spells (what is cast from a slot), in order.
static func spells() -> Array[StringName]:
	return ids().filter(func(a: StringName) -> bool: return is_spell(a))


## The slot `a` takes, or &"" for a perk (or anything that is not an ability).
static func slot_of(a: StringName) -> StringName:
	return StringName(ABILITIES[a].get("slot", &"")) if ABILITIES.has(a) else &""


## Everything that takes slot `slot`, in order (worked out once a slot: the art asks every frame).
static func in_slot(slot: StringName) -> Array[StringName]:
	if not _in_slot.has(slot):
		var out: Array[StringName] = []
		for a: StringName in ABILITIES:
			if slot_of(a) == slot:
				out.append(a)
		_in_slot[slot] = out
	return (_in_slot[slot] as Array[StringName]).duplicate()


## What in_slot has worked out, by slot (ABILITIES never changes).
static var _in_slot: Dictionary = {}


## What takes slot `slot` (in_slot's list itself, not a copy), for asking what is in it.
static func _slot_list(slot: StringName) -> Array[StringName]:
	in_slot(slot)
	return _in_slot[slot]


## Whether `a` is a spell: it takes a slot and is cast (not the dash or blink, the wizard's own
## moves); false for anything that is not an ability (a glow name such as &"climb", see
## RisoPrint.flare).
static func is_spell(a: StringName) -> bool:
	return slot_of(a) != &"" and bool(ABILITIES[a].get("cast", true))


static func max_tier(a: StringName) -> int:
	return int(ABILITIES[a]["max"])


## How it is named on screen: its id, words apart.
static func label(a: StringName) -> String:
	return String(a).replace("_", " ")


static func start_tiers() -> Dictionary:
	var tiers: Dictionary = {}
	for a: StringName in ABILITIES:
		tiers[a] = int(ABILITIES[a].get("base", 0))
	return tiers


static func tier(player: Player, a: StringName) -> int:
	return int(player.tiers.get(a, 0))


## What is in slot `slot` (the damage slot unless said), or &"" when it is empty.
static func spell(player: Player, slot: StringName = &"damage") -> StringName:
	for a: StringName in _slot_list(slot):
		if tier(player, a) > 0:
			return a
	return &""


## Stars to learn `next_tier` of an ability at `depth`: dearer per tier, cheaper deeper.
static func price(depth: int, next_tier: int) -> int:
	return maxi(6, roundi(20.0 * pow(1.6, next_tier - 1) * pow(0.8, depth)))


## Stars a cast of spell `a` costs at `depth` (0 for a free spell): a little dearer deeper, as
## stars get more plentiful.
static func cast_price(a: StringName, depth: int) -> int:
	if not ABILITIES.has(a) or not ABILITIES[a].has("cost"):
		return 0
	return maxi(1, roundi(float(ABILITIES[a]["cost"]) * pow(1.25, maxi(depth, 0))))


## What a cast of the spell in slot `slot` costs where the wizard is.
static func cast_price_here(player: Player, slot: StringName = &"damage") -> int:
	var depth: int = MapInfo.instance.here.depth if MapInfo.instance != null else 0
	return cast_price(spell(player, slot), depth)


## Stars to heal to full at `depth`: the opposite of learning, dearer deeper.
static func heal_price(depth: int) -> int:
	return roundi(6.0 * pow(1.35, depth))


## What a level's shrine teaches. Starting from an ability picked by the level seed and going
## round, the first one not yet known; once everything is known, the first with a tier left to
## learn.
static func offer(level_seed: int, player: Player) -> StringName:
	var all: Array[StringName] = offers(level_seed, player, 1)
	return all[0] if not all.is_empty() else &""


## Up to `count` different abilities a shrine offers, in that order (new ones before upgrades).
## At least one is always a strict upgrade, a gain with nothing given up: a new perk or the next
## tier of something already known, never a spell that would replace the one in the slot. If
## every pick would be a swap, the last is traded for the first strict upgrade left. (Something
## for a slot that is empty is a strict upgrade.)
static func offers(level_seed: int, player: Player, count: int) -> Array[StringName]:
	var out: Array[StringName] = _picks(level_seed, player, count, false)
	if out.is_empty() or out.any(func(a: StringName) -> bool: return not is_swap(player, a)):
		return out
	var strict: Array[StringName] = _picks(level_seed, player, 1, true)
	if not strict.is_empty():
		out[out.size() - 1] = strict[0]
	return out


## The shrine's picks in order (see offers), only strict upgrades when `strict`.
static func _picks(level_seed: int, player: Player, count: int, strict: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	var order: Array[StringName] = ids()
	var n: int = order.size()
	var start: int = level_seed % n
	for pass_new: bool in [true, false]:
		for i: int in range(n):
			if out.size() >= count:
				return out
			var a: StringName = order[(start + i) % n]
			if a in out:
				continue
			# The big moves are found as relics first (see Relics); then their higher tiers are taught.
			if a in Relics.MOVES and tier(player, a) == 0:
				continue
			if pass_new and tier(player, a) > 0:
				continue
			if strict and is_swap(player, a):
				continue
			if tier(player, a) < max_tier(a):
				out.append(a)
	return out


## Would learning `a` replace what is in its slot?
static func is_swap(player: Player, a: StringName) -> bool:
	var slot: StringName = slot_of(a)
	if slot == &"":
		return false
	var held: StringName = spell(player, slot)
	return held != &"" and held != a


static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## Learn the next tier of `a`. Something for a slot replaces what is in it.
static func grant(player: Player, a: StringName) -> void:
	_take_slot(player, a)
	player.tiers[a] = mini(tier(player, a) + 1, max_tier(a))
	apply(player)
	if a == &"vigor":
		player.health.health = mini(player.health.health + 1, player.health.max_health)
	elif a == &"mend":
		# Learning a tier fills the draughts.
		(player.get_node("Mend") as Mend).refill()


## Set ability `a` to tier `n` outright (the debug picker on the F7 panel). Something for a slot
## set above 0 takes it, emptying it of the rest.
static func set_tier(player: Player, a: StringName, n: int) -> void:
	n = clampi(n, 0, max_tier(a))
	if n > 0:
		_take_slot(player, a)
	player.tiers[a] = n
	apply(player)


## `a` takes its slot: everything else for that slot is forgotten.
static func _take_slot(player: Player, a: StringName) -> void:
	var slot: StringName = slot_of(a)
	if slot == &"":
		return
	for other: StringName in in_slot(slot):
		if other != a:
			player.tiers[other] = 0


## Back to a new run's abilities, at full health.
static func reset(player: Player) -> void:
	player.tiers = start_tiers()
	Mend.restore(player, -1)
	apply(player)
	player.health.health = player.health.max_health


## Adds the Spell and Utility actions if the project does not define them.
static func ensure_input() -> void:
	if not InputMap.has_action(SPELL_ACTION):
		InputMap.add_action(SPELL_ACTION)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_Q
		InputMap.action_add_event(SPELL_ACTION, key)
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_X
		InputMap.action_add_event(SPELL_ACTION, pad)
	if not InputMap.has_action(UTILITY_ACTION):
		InputMap.add_action(UTILITY_ACTION)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event(UTILITY_ACTION, key)
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event(UTILITY_ACTION, pad)


## A slot's button: cast the spell in slot `slot` (its node's cast_spell; the dash and blink are
## the wizard's own, see Player). A spell with a cast price ("cost") is only cast when the stars
## are there, and they are paid only if it works. Nothing is cast while the wizard is drowsy (in
## sleep fog). Returns whether it was cast.
static func cast(player: Player, slot: StringName = &"damage") -> bool:
	# Drowsy in sleep fog: no spells.
	if player.is_drowsy() or not is_spell(spell(player, slot)):
		return false
	var cost: int = cast_price_here(player, slot)
	if cost > player.coins.coins:
		return false
	var node: Node = spell_node(player, slot)
	if node == null or not bool(node.call(&"cast_spell")):
		return false
	if cost > 0:
		player.collect(-cost)
	return true


## The node of the spell in slot `slot`, or null when there is none (the slot empty, the dash in
## it, or its node not made yet).
static func spell_node(player: Player, slot: StringName = &"damage") -> Node:
	var a: StringName = spell(player, slot)
	if not is_spell(a):
		return null
	return player.get_node_or_null(String(ABILITIES[a]["node"]))


## How ready the spell in slot `slot` is to cast, 0..1 (1 when it can be), as its node says
## (`readiness`); -1 when the slot is empty. Drowsy in sleep fog, or short of the stars a cast
## costs, it is 0.
static func readiness(player: Player, slot: StringName = &"damage") -> float:
	if spell(player, slot) == &"":
		return -1.0
	if player.is_drowsy() or cast_price_here(player, slot) > player.coins.coins:
		return 0.0
	var node: Node = spell_node(player, slot)
	return float(node.call(&"readiness")) if node != null else 1.0


## The spell in slot `slot` while it runs, as its node says (`running`): (the fraction of its time
## left, seconds left); x < 0 when nothing is running.
static func running(player: Player, slot: StringName = &"damage") -> Vector2:
	var node: Node = spell_node(player, slot)
	return node.call(&"running") as Vector2 if node != null else Vector2(-1.0, 0.0)


## Push every tier into the wizard: its own moves (Player.tune_moves), then each ability's node,
## made or taken away as the ability is known or not, and told its tier.
static func apply(player: Player) -> void:
	player.tune_moves()
	for a: StringName in ABILITIES:
		var entry: Dictionary = ABILITIES[a]
		if not entry.has("node"):
			continue
		var n: int = tier(player, a)
		var node: Node = _node_for(player, entry, n > 0 or bool(entry.get("always", false)))
		if node != null:
			node.call(&"set_tier", n)


## The node of an ability described by `entry`: made when it is `known` (and made on demand),
## taken away (told it is at tier 0 first) when it is not. Null when there is none.
static func _node_for(player: Player, entry: Dictionary, known: bool) -> Node:
	var node_name: String = entry["node"]
	var node: Node = player.get_node_or_null(node_name)
	if not entry.has("make"):
		return node
	if known and node == null:
		var made: Resource = load(String(entry["make"]))
		node = (made as PackedScene).instantiate() if made is PackedScene else (made as GDScript).new()
		node.name = node_name
		player.add_child(node)
	elif not known and node != null:
		node.call(&"set_tier", 0)
		player.remove_child(node)
		node.queue_free()
		node = null
	return node
