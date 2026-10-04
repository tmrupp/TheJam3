class_name Abilities
## Tiered abilities, learned at shrines (there is no shop), except that tier I of the big moves
## (double jump, wall climb, blink, levitate) only comes from a relic (see Relics). Tier 0 is not owned; the dash and the
## hex (the starting spell) are known from the start (tier 1). Each tier improves the ability.
## Tiers live on the player and reset when a run ends.
## - Spells share one slot, on the Spell button (Q, or the pad's X): hex, astral projection,
##   parry, levitate, awareness, rift (open your own teleporters) and warp (to a random floor). You carry one at a time; learning another at a shrine
##   replaces it.
## - Perks stack: double jump, wall climb, blink (replaces the dash), vigor (max health) and
##   speed (run speed).

const ORDER: Array[StringName] = [&"dash", &"double_jump", &"wall_climb", &"blink", &"parry", &"astral", &"hex", &"levitate", &"awareness", &"rift", &"vigor", &"speed", &"warp"]
## Run speed added per tier of speed, as a fraction of the base.
const SPEED_PER_TIER: float = 0.15
const SPELLS: Array[StringName] = [&"hex", &"astral", &"parry", &"levitate", &"awareness", &"rift", &"warp"]
const NAMES: Dictionary = {
	&"dash": "dash",
	&"double_jump": "double jump",
	&"wall_climb": "wall climb",
	&"blink": "blink",
	&"parry": "parry",
	&"astral": "astral",
	&"hex": "hex",
	&"levitate": "levitate",
	&"awareness": "awareness",
	&"rift": "rift",
	&"vigor": "vigor",
	&"speed": "speed",
	&"warp": "warp",
}
const BASE: Dictionary = {&"dash": 1, &"hex": 1}
const MAX: Dictionary = {&"dash": 4, &"double_jump": 3, &"wall_climb": 3, &"blink": 3, &"parry": 4, &"astral": 4, &"hex": 4,
	&"levitate": 3, &"awareness": 3, &"rift": 3, &"vigor": 3, &"speed": 3, &"warp": 3}
const BLINK_PREFAB: String = "res://prefabs/upgrades/Blink.tscn"
const BASE_HEALTH: int = 3
const SPELL_ACTION: StringName = &"Spell"


static func start_tiers() -> Dictionary:
	var tiers: Dictionary = {}
	for a: StringName in ORDER:
		tiers[a] = int(BASE.get(a, 0))
	return tiers


static func tier(player: Player, a: StringName) -> int:
	return int(player.tiers.get(a, 0))


## The spell in the slot, or &"" when it is empty.
static func spell(player: Player) -> StringName:
	for a: StringName in SPELLS:
		if tier(player, a) > 0:
			return a
	return &""


## Stars to learn `next_tier` of an ability at `depth`: dearer per tier, cheaper deeper.
static func price(depth: int, next_tier: int) -> int:
	return maxi(3, roundi(10.0 * pow(1.6, next_tier - 1) * pow(0.8, depth)))


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
	var n: int = ORDER.size()
	var start: int = level_seed % n
	for pass_new: bool in [true, false]:
		for i: int in range(n):
			if out.size() >= count:
				return out
			var a: StringName = ORDER[(start + i) % n]
			if a in out or (a == &"dash" and tier(player, &"blink") > 0):
				continue
			# The big moves are found as relics first (see Relics); then their higher tiers are taught.
			if a in Relics.MOVES and tier(player, a) == 0:
				continue
			if pass_new and tier(player, a) > 0:
				continue
			if strict and is_swap(player, a):
				continue
			if tier(player, a) < int(MAX[a]):
				out.append(a)
	return out


## Would learning `a` replace the spell in the slot?
static func is_swap(player: Player, a: StringName) -> bool:
	var held: StringName = spell(player)
	return a in SPELLS and held != &"" and held != a


static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## Learn the next tier of `a`. A new spell replaces the one in the slot.
static func grant(player: Player, a: StringName) -> void:
	if a in SPELLS:
		for other: StringName in SPELLS:
			if other != a:
				player.tiers[other] = 0
	player.tiers[a] = mini(tier(player, a) + 1, int(MAX[a]))
	apply(player)
	if a == &"vigor":
		player.health.health = mini(player.health.health + 1, player.health.max_health)
		player.health.display_health()


## Set ability `a` to tier `n` outright (the debug picker on the F7 panel). A spell set above 0
## takes the slot, emptying the others.
static func set_tier(player: Player, a: StringName, n: int) -> void:
	n = clampi(n, 0, int(MAX[a]))
	if a in SPELLS and n > 0:
		for other: StringName in SPELLS:
			if other != a:
				player.tiers[other] = 0
	player.tiers[a] = n
	apply(player)


## Back to a new run's abilities, at full health.
static func reset(player: Player) -> void:
	player.tiers = start_tiers()
	apply(player)
	player.health.health = player.health.max_health
	player.health.display_health()


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


## The Spell button: use whatever is in the slot.
static func cast(player: Player) -> void:
	match spell(player):
		&"hex":
			(player.get_node("Hex") as Hex).cast()
		&"astral":
			player.get_node("AstralProjection").call("toggle")
		&"parry":
			player.parry.emit()
		&"levitate":
			(player.get_node("Levitate") as Levitate).toggle()
		&"awareness":
			(player.get_node("Awareness") as Awareness).ping()
		&"rift":
			(player.get_node("Rift") as Rift).cast()
		&"warp":
			(player.get_node("Warp") as Warp).cast()


## A child node that exists only while its ability is known.
static func _keep(player: Player, node_name: String, known: bool, make: Callable) -> Node:
	var node: Node = player.get_node_or_null(node_name)
	if known and node == null:
		node = make.call()
		node.name = node_name
		player.add_child(node)
	elif not known and node != null:
		player.remove_child(node)
		node.queue_free()
		node = null
	return node


## Push every tier into the player's tuning.
static func apply(player: Player) -> void:
	var dash: int = tier(player, &"dash")
	player.dash.MAX_TIME = 0.25 + 0.07 * float(maxi(dash, 1) - 1)
	player.MAX_JUMPS = 1 + tier(player, &"double_jump")
	player.jumps = mini(player.jumps, player.MAX_JUMPS)
	var climb: int = tier(player, &"wall_climb")
	player.climable = climb > 0
	player.climb.MAX_TIME = Player.CLIMB_TIME + 0.5 * float(maxi(climb, 1) - 1)
	var blink: int = tier(player, &"blink")
	var blink_node: Node = player.get_node_or_null("Blink")
	if blink > 0 and blink_node == null:
		blink_node = (load(BLINK_PREFAB) as PackedScene).instantiate()
		player.add_child(blink_node)
	elif blink == 0 and blink_node != null:
		player.remove_child(blink_node)
		blink_node.queue_free()
		blink_node = null
		player.dash_ability = player.do_dash
	if blink_node != null:
		blink_node.set("distance", 300 + 100 * (blink - 1))
	var parry: int = maxi(tier(player, &"parry"), 1)
	var parry_node: Node = player.get_node_or_null("Parry")
	if parry_node != null:
		# I: the guard (0.3 s), 1 damage, reflects shots, refunds the dash. II: 0.45 s and a shorter
		# cooldown on a miss. III: 2 damage. IV: each parry heals 1.
		parry_node.set("duration", 0.45 if parry >= 2 else 0.3)
		parry_node.set("damage", 2 if parry >= 3 else 1)
		parry_node.set("heals", parry >= 4)
		var cooldown: ActionTimer = parry_node.get("cooldown") as ActionTimer
		if cooldown != null:
			cooldown.MAX_TIME = 0.9 if parry >= 2 else 1.2
	var astral: int = maxi(tier(player, &"astral"), 1)
	var projection: Node = player.get_node_or_null("AstralProjection")
	if projection != null:
		(projection.get("projection_timer") as ActionTimer).MAX_TIME = 5.0 + 2.0 * float(astral - 1)
		# Swapped away mid-projection: snap back.
		if tier(player, &"astral") == 0 and bool(projection.call("projecting")):
			projection.call("end_projection", projection.get("projection_timer"))
	var hex_tier: int = tier(player, &"hex")
	var hex: Hex = _keep(player, "Hex", hex_tier > 0, func() -> Node: return Hex.new()) as Hex
	if hex != null:
		hex.charges_max = 1 + (1 if hex_tier >= 3 else 0)
		hex.damage = (1 if hex_tier >= 2 else 0) + (1 if hex_tier >= 4 else 0)
		hex.pierce = hex_tier >= 4
		hex.charges = mini(hex.charges, hex.charges_max)
	var lev_tier: int = tier(player, &"levitate")
	if lev_tier == 0:
		player.levitating = false
	var lev: Levitate = _keep(player, "Levitate", lev_tier > 0, func() -> Node: return Levitate.new()) as Levitate
	if lev != null:
		lev.drift = lev_tier >= 2
		lev.free_recast = lev_tier >= 3
	var aware_tier: int = tier(player, &"awareness")
	var aware: Awareness = _keep(player, "Awareness", aware_tier > 0, func() -> Node: return Awareness.new()) as Awareness
	if aware != null:
		aware.level = aware_tier
	var rift_tier: int = tier(player, &"rift")
	var rift: Rift = _keep(player, "Rift", rift_tier > 0, func() -> Node: return Rift.new()) as Rift
	if rift != null:
		rift.level = rift_tier
		rift.sync_ends()
	var warp_tier: int = tier(player, &"warp")
	var warp: Warp = _keep(player, "Warp", warp_tier > 0, func() -> Node: return Warp.new()) as Warp
	if warp != null:
		warp.level = warp_tier
	player.run_speed = Player.SPEED * (1.0 + SPEED_PER_TIER * float(tier(player, &"speed")))
	player.health.max_health = BASE_HEALTH + tier(player, &"vigor")
	player.health.health = mini(player.health.health, player.health.max_health)
	player.health.display_health()
