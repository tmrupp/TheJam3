class_name Abilities
## Tiered abilities, learned at shrines (there is no shop). Tier 0 is not owned; only the dash
## is known from the start (tier 1). Everything else, including parry, astral projection (the
## orbs stay dormant until then) and the hex, has to be found. Each tier improves the ability, and
## vigor raises max health. Tiers live on the player and reset when a run ends.

const ORDER: Array[StringName] = [&"dash", &"double_jump", &"wall_climb", &"blink", &"parry", &"astral", &"hex", &"vigor"]
const NAMES: Dictionary = {
	&"dash": "dash",
	&"double_jump": "double jump",
	&"wall_climb": "wall climb",
	&"blink": "blink",
	&"parry": "parry",
	&"astral": "astral",
	&"hex": "hex",
	&"vigor": "vigor",
}
const BASE: Dictionary = {&"dash": 1}
const MAX: Dictionary = {&"dash": 4, &"double_jump": 3, &"wall_climb": 3, &"blink": 3, &"parry": 4, &"astral": 4, &"hex": 4, &"vigor": 3}
const BLINK_PREFAB: String = "res://prefabs/upgrades/Blink.tscn"
const BASE_HEALTH: int = 3


static func start_tiers() -> Dictionary:
	var tiers: Dictionary = {}
	for a: StringName in ORDER:
		tiers[a] = int(BASE.get(a, 0))
	return tiers


static func tier(player: Player, a: StringName) -> int:
	return int(player.tiers.get(a, 0))


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
	var n: int = ORDER.size()
	var start: int = level_seed % n
	for pass_new: bool in [true, false]:
		for i: int in range(n):
			var a: StringName = ORDER[(start + i) % n]
			if a == &"dash" and tier(player, &"blink") > 0:
				continue
			if pass_new and tier(player, a) > 0:
				continue
			if tier(player, a) < int(MAX[a]):
				return a
	return &""


static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


## Learn the next tier of `a`.
static func grant(player: Player, a: StringName) -> void:
	player.tiers[a] = mini(tier(player, a) + 1, int(MAX[a]))
	apply(player)
	if a == &"vigor":
		player.health.health = mini(player.health.health + 1, player.health.max_health)
		player.health.display_health()


## Back to a new run's abilities, at full health.
static func reset(player: Player) -> void:
	player.tiers = start_tiers()
	apply(player)
	player.health.health = player.health.max_health
	player.health.display_health()


## Push every tier into the player's tuning.
static func apply(player: Player) -> void:
	var dash: int = tier(player, &"dash")
	player.dash.MAX_TIME = 0.25 + 0.07 * float(maxi(dash, 1) - 1)
	player.MAX_JUMPS = 1 + tier(player, &"double_jump")
	player.jumps = mini(player.jumps, player.MAX_JUMPS)
	var climb: int = tier(player, &"wall_climb")
	player.climable = climb > 0
	player.climb.MAX_TIME = Player.CLIMB_TIME + 1.5 * float(maxi(climb, 1) - 1)
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
		parry_node.set("duration", 0.3 + 0.1 * float(parry - 1))
		var cooldown: ActionTimer = parry_node.get("cooldown") as ActionTimer
		if cooldown != null:
			cooldown.MAX_TIME = 2.0 - 0.4 * float(parry - 1)
	var astral: int = maxi(tier(player, &"astral"), 1)
	var projection: Node = player.get_node_or_null("AstralProjection")
	if projection != null:
		(projection.get("projection_timer") as ActionTimer).MAX_TIME = 5.0 + 2.0 * float(astral - 1)
	var hex_tier: int = tier(player, &"hex")
	var hex: Hex = player.get_node_or_null("Hex") as Hex
	if hex_tier > 0 and hex == null:
		hex = Hex.new()
		hex.name = "Hex"
		player.add_child(hex)
	elif hex_tier == 0 and hex != null:
		player.remove_child(hex)
		hex.queue_free()
		hex = null
	if hex != null:
		hex.charges_max = 1 + (1 if hex_tier >= 2 else 0)
		hex.damage = 1 + (1 if hex_tier >= 3 else 0)
		hex.pierce = hex_tier >= 4
		hex.charges = mini(hex.charges, hex.charges_max)
	player.health.max_health = BASE_HEALTH + tier(player, &"vigor")
	player.health.health = mini(player.health.health, player.health.max_health)
	player.health.display_health()
