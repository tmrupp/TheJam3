class_name Abilities
## Tiered abilities, learned at shrines (there is no shop), except that tier I of the big moves
## (double jump, wall climb, blink, levitate, astral projection) only comes from a relic (see Relics). Tier 0 is not owned; only the dash
## is known from the start (tier 1), and the spell slot starts empty. The dash is the wizard's
## attack (DashStrike); the strike perk makes it wound. Each tier improves the ability.
## Tiers live on the player and reset when a run ends.
## - Spells share one slot, on the Spell button (Q, or the pad's X): hex, astral projection,
##   parry, levitate, awareness, rift (open your own teleporters), warp (to a random floor) and mend
##   (heal from draughts a burned lantern fills, see Mend). You carry one at a time; learning another
##   at a shrine replaces it. Warp and rift cost stars each cast (cast_price).
## - Perks stack: double jump, wall climb, blink (replaces the dash), vigor (max health),
##   speed (run speed), keyring (carry more keys, see KeyRing) and strike (the dash wounds).
##
## Every ability is one entry in ABILITIES. What a tier does lives with whatever does the ability:
## a node on the wizard (its `set_tier`, and `cast_spell` for a spell), or, for the wizard's own
## moves (the dash, double jump, wall climb, speed, vigor), Player.tune_moves. A new ability is an
## entry here, its node (or a line in tune_moves), and its mark (RisoGlyph).

## Every ability, in the order shrines go round them (see offers):
## - "max": its top tier; "base": the tier a run starts with (0 when not given);
## - "spell": true for the spells, which share the slot; "cost": stars a cast at depth 0 (see
##   cast_price), for a spell that costs any;
## - "node": the wizard's child that does it, told its tier by `set_tier(n)` (and cast by
##   `cast_spell() -> bool` when a spell). With "make" (the path of its script, or of its scene)
##   it exists only while the ability is known (or always, with "always"); without, it is part of
##   the wizard's scene.
const ABILITIES: Dictionary = {
	&"dash": {"max": 4, "base": 1},
	&"double_jump": {"max": 3},
	&"wall_climb": {"max": 3},
	&"blink": {"max": 3, "node": "Blink", "make": "res://prefabs/upgrades/Blink.tscn"},
	&"parry": {"max": 4, "spell": true, "node": "Parry"},
	&"astral": {"max": 4, "spell": true, "node": "AstralProjection"},
	&"hex": {"max": 4, "spell": true, "node": "Hex", "make": "res://scripts/Hex.gd"},
	&"levitate": {"max": 3, "spell": true, "node": "Levitate", "make": "res://scripts/Levitate.gd"},
	&"awareness": {"max": 3, "spell": true, "node": "Awareness", "make": "res://scripts/Awareness.gd"},
	&"rift": {"max": 3, "spell": true, "cost": 1.0, "node": "Rift", "make": "res://scripts/Rift.gd"},
	&"vigor": {"max": 3},
	&"speed": {"max": 3},
	&"warp": {"max": 3, "spell": true, "cost": 2.0, "node": "Warp", "make": "res://scripts/Warp.gd"},
	&"mend": {"max": 3, "spell": true, "node": "Mend", "make": "res://scripts/Mend.gd"},
	&"keyring": {"max": 3},
	&"strike": {"max": 3, "node": "DashStrike", "make": "res://scripts/DashStrike.gd", "always": true},
}
## Run speed added per tier of speed, as a fraction of the base.
const SPEED_PER_TIER: float = 0.15
const BASE_HEALTH: int = 3
const SPELL_ACTION: StringName = &"Spell"


## Every ability, in order (see ABILITIES).
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a: StringName in ABILITIES:
		out.append(a)
	return out


## The spells, in order.
static func spells() -> Array[StringName]:
	return ids().filter(func(a: StringName) -> bool: return is_spell(a))


static func is_spell(a: StringName) -> bool:
	return bool(ABILITIES[a].get("spell", false))


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


## The spell in the slot, or &"" when it is empty.
static func spell(player: Player) -> StringName:
	for a: StringName in spells():
		if tier(player, a) > 0:
			return a
	return &""


## Stars to learn `next_tier` of an ability at `depth`: dearer per tier, cheaper deeper.
static func price(depth: int, next_tier: int) -> int:
	return maxi(3, roundi(10.0 * pow(1.6, next_tier - 1) * pow(0.8, depth)))


## Stars a cast of spell `a` costs at `depth` (0 for a free spell): a little dearer deeper, as
## stars get more plentiful.
static func cast_price(a: StringName, depth: int) -> int:
	if not ABILITIES.has(a) or not ABILITIES[a].has("cost"):
		return 0
	return maxi(1, roundi(float(ABILITIES[a]["cost"]) * pow(1.25, maxi(depth, 0))))


## What a cast of the spell in the slot costs where the wizard is.
static func cast_price_here(player: Player) -> int:
	var depth: int = MapInfo.instance.here.depth if MapInfo.instance != null else 0
	return cast_price(spell(player), depth)


## Stars to heal to full at `depth`: the opposite of learning, dearer deeper.
static func heal_price(depth: int) -> int:
	return roundi(3.0 * pow(1.35, depth))


## What a level's shrine teaches. Starting from an ability picked by the level seed and going
## round, the first one not yet known; once everything is known, the first with a tier left to
## learn. Dash tiers are not offered once blink replaces the dash.
static func offer(level_seed: int, player: Player) -> StringName:
	var all: Array[StringName] = offers(level_seed, player, 1)
	return all[0] if not all.is_empty() else &""


## Up to `count` different abilities a shrine offers, in that order (new ones before upgrades).
## At least one is always a strict upgrade, a gain with nothing given up: a new perk or the next
## tier of something already known, never a spell that would replace the one in the slot. If
## every pick would be a swap, the last is traded for the first strict upgrade left.
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
			if a in out or (a == &"dash" and tier(player, &"blink") > 0):
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


## Would learning `a` replace the spell in the slot?
static func is_swap(player: Player, a: StringName) -> bool:
	var held: StringName = spell(player)
	return is_spell(a) and held != &"" and held != a


static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## Learn the next tier of `a`. A new spell replaces the one in the slot.
static func grant(player: Player, a: StringName) -> void:
	_take_slot(player, a)
	player.tiers[a] = mini(tier(player, a) + 1, max_tier(a))
	apply(player)
	if a == &"vigor":
		player.health.health = mini(player.health.health + 1, player.health.max_health)
	elif a == &"mend":
		# Learning a tier fills the draughts.
		(player.get_node("Mend") as Mend).refill()


## Set ability `a` to tier `n` outright (the debug picker on the F7 panel). A spell set above 0
## takes the slot, emptying the others.
static func set_tier(player: Player, a: StringName, n: int) -> void:
	n = clampi(n, 0, max_tier(a))
	if n > 0:
		_take_slot(player, a)
	player.tiers[a] = n
	apply(player)


## A spell `a` takes the slot: every other spell is forgotten.
static func _take_slot(player: Player, a: StringName) -> void:
	if not is_spell(a):
		return
	for other: StringName in spells():
		if other != a:
			player.tiers[other] = 0


## Back to a new run's abilities, at full health.
static func reset(player: Player) -> void:
	player.tiers = start_tiers()
	Mend.restore(player, -1)
	apply(player)
	player.health.health = player.health.max_health


## Adds the Spell action if the project does not define it.
static func ensure_input() -> void:
	if InputMap.has_action(SPELL_ACTION):
		return
	InputMap.add_action(SPELL_ACTION)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_Q
	InputMap.action_add_event(SPELL_ACTION, key)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	InputMap.action_add_event(SPELL_ACTION, pad)


## The Spell button: cast whatever is in the slot (its node's cast_spell). A spell with a cast
## price ("cost") is only cast when the stars are there, and they are paid only if it works.
## Nothing is cast while the wizard is drowsy (in sleep fog).
static func cast(player: Player) -> void:
	# Drowsy in sleep fog: no spells.
	if player.is_drowsy():
		return
	var cost: int = cast_price_here(player)
	if cost > player.coins.coins:
		return
	var a: StringName = spell(player)
	if a == &"":
		return
	var node: Node = player.get_node_or_null(String(ABILITIES[a]["node"]))
	if node != null and bool(node.call(&"cast_spell")) and cost > 0:
		player.collect(-cost)


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
