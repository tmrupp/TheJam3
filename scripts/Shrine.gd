extends Node2D
class_name Shrine
## A level's shrine, near its deeper exit, across two cells. It offers three things; taking any
## one spends it:
## - two boons: the next tier of two different abilities (picked by the level seed, new ones
##   before upgrades), cheaper deeper; a place may set its own instead (NextWorldDef.boons: the
##   tutorial's, a strict upgrade against a swap);
## - its third station (station): mending while the wizard is hurt, free, healing to full and
##   filling the utility spell held (mend's draughts, resurrect's rites); at full health instead,
##   for stars and a key (KEY_COST, one of those carried, dealt by the shrine, taken_key), a door
##   on where the labyrinth left the level none (sells_door), the whereabouts of the nearest relic
##   not yet found (see Relics), marked on the worlds map, or a skeleton key (sells_skeleton), laid
##   somewhere in the level for the wizard to find.
## And two things that do not spend it (docs/REVIEW_PLAN.md §7):
## - between the niches, drawing its boons again (buy_redraw): stars (REDRAW_PRICE times the way
##   on, doubling with each draw there) and a carried key (redraw_key), while it is unspent, in any
##   place but the tutorial;
## - at its far end, which way the boss ahead lies (buy_way: left, right or this column,
##   Bosses.column), for stars alone (boss_price), at any health, while that boss lives, once a
##   column (told_way).
## Pay to learn. There is no menu: interact with the one you want.
## A spell learned in place of the one in the slot hands the old one back as an exam paper, at its
## tier (MapInfo.put_back), to be learned again at a lantern.

const BOONS: int = 2

@onready var player: Player = Stage.player()

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


func depth() -> int:
	return map_info.here.depth if map_info != null and map_info.here != null else 0


func used() -> bool:
	return map_info == null or bool(map_info.record().shrine_used)


## The two boons: the ones the place sets itself (NextWorldDef.boons, the tutorial's), else the
## usual ones by the level seed.
func offers() -> Array[StringName]:
	if map_info == null:
		return []
	var own: Array[StringName] = map_info.here.boons(player) if map_info.here != null else ([] as Array[StringName])
	if not own.is_empty():
		return own
	return Abilities.offers(offer_seed(redraws()), player, BOONS)


## The seed its boons are dealt by after `draws` draws again: the level seed, then that hashed with
## REDRAW_DEAL and the count (no world RNG, so a shrine drawn twice shows the same pair on every
## visit and in every run that draws it twice).
func offer_seed(draws: int) -> int:
	var base: int = Rules.level_seed(map_info.coord.x, map_info.coord.y)
	return base if draws <= 0 else Rules.level_seed(base, REDRAW_DEAL + draws)


# ------------------------------------------------------------------ drawing the boons again

## Salts for the level seed: the boons drawn again (offer_seed), and which carried key each draw
## takes (redraw_key).
const REDRAW_DEAL: int = 6800
const REDRAW_KEY_DEAL: int = 6900
## A draw's price in stars: REDRAW_PRICE times the level's way on, doubled for each draw already
## made at this shrine; and one carried key besides (KEY_COST).
const REDRAW_PRICE: float = 0.5
## How many counts on a draw looks for a pair unlike the one shown before giving up on finding one.
const REDRAW_TRIES: int = 6


## How many times its boons have been drawn again.
func redraws() -> int:
	return int(map_info.record().redraws) if map_info != null else 0


## Whether its boons can be drawn again: unspent, with boons to show, not the tutorial's own.
func can_redraw() -> bool:
	if map_info == null or used() or map_info.here is Tutorial:
		return false
	if map_info.here != null and not map_info.here.boons(player).is_empty():
		return false
	return not offers().is_empty()


## The stars the next draw costs.
func redraw_price() -> int:
	return roundi(REDRAW_PRICE * float(Rules.deeper_price(depth())) * pow(2.0, float(redraws())))


## The carried key the next draw takes (dealt by the shrine and the draw's count, so the same on
## every visit), or -1 with none carried.
func redraw_key() -> int:
	if map_info == null:
		return -1
	return pick_key(carried_keys(), false, Rules.level_seed(Rules.level_seed(map_info.coord.x, map_info.coord.y), REDRAW_KEY_DEAL + redraws()))


## Draw its boons again, for redraw_price and redraw_key: nothing is taken, and nothing drawn,
## unless both can be paid. A draw that would show the same pair is passed over for the next.
func buy_redraw() -> void:
	if not can_redraw():
		return
	var key: int = redraw_key()
	if key < 0 or player.coins.coins < redraw_price():
		return
	var was: Array[StringName] = offers()
	player.collect(-redraw_price())
	player.keyring.spend(key)
	var rec: LevelRecord = map_info.record()
	for i: int in range(REDRAW_TRIES):
		rec.redraws += 1
		if offers() != was:
			break
	map_info.save_run()
	RisoFx.burst(&"gain", ($Redraw as Node2D).global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])


## The ability in niche `i` (0 or 1), or &"" when there is nothing left to offer there.
func offer(i: int = 0) -> StringName:
	var all: Array[StringName] = offers()
	return all[i] if i < all.size() else &""


func offer_tier(i: int = 0) -> int:
	return Abilities.tier(player, offer(i)) + 1


## Learning niche `i` would replace what is in its slot.
func swap(i: int = 0) -> bool:
	return Abilities.is_swap(player, offer(i))


func offer_price(i: int = 0) -> int:
	return Abilities.price(depth(), offer_tier(i))


func can_mend() -> bool:
	return player.health.health < player.health.max_health


func buy_boon(i: int = 0) -> void:
	if used():
		return
	var a: StringName = offer(i)
	if a == &"":
		return
	# Something that replaces what is in its slot hands the old one back as a paper, at its tier.
	var dropped: StringName = Abilities.spell(player, Abilities.slot_of(a)) if swap(i) else &""
	var dropped_tier: int = Abilities.tier(player, dropped) if dropped != &"" else 0
	if not _pay(offer_price(i)):
		return
	Abilities.grant(player, a)
	var niche: Node2D = get_node("Boon" if i == 0 else "Boon2") as Node2D
	if dropped != &"":
		map_info.put_back(dropped, dropped_tier, niche.global_position + Vector2(0, -40))
	_spend(get_node("Boon" if i == 0 else "Boon2") as Node2D, [RisoPrint.ACCENT, RisoPrint.PINK])


## What the third station offers now: &"mend" while the wizard is hurt; else &"door" (sells_door),
## &"relic" (the nearest relic's whereabouts) or &"skeleton" (a skeleton key); &"" with no shrine
## run to ask.
func station() -> StringName:
	if can_mend():
		return &"mend"
	if map_info == null:
		return &""
	if door_wanted() and sells_door_at(map_info.coord):
		return &"door"
	if map_info.next_relic() == null or sells_skeleton_at(map_info.coord, not map_info.run.relic_hints.is_empty()):
		return &"skeleton"
	return &"relic"


## Keys the third station takes, besides its stars, for anything but mending: one of the colours
## carried, dealt by the shrine (taken_key).
const KEY_COST: int = 1
## How heavily each key colour weighs when the third station deals which carried key it takes for
## a relic's whereabouts: the rarer the colour, the likelier it goes (Rules.KEY_RARITY). For a door
## or a skeleton key, and for drawing the boons again, every carried colour weighs the same.
const RELIC_KEY_WEIGHT: Array[int] = [1, 2, 4, 8]
## Salt for the level seed when dealing which carried key the third station takes.
const KEY_DEAL: int = 6600


## The key the third station would take now: one of the coloured keys carried (papers and the kept
## skeleton keys and relic unlocks are no price), dealt by the shrine's level seed (pick_key), so a
## shrine asks the same key of the same ring; or -1 for none carried or none asked (mending).
func taken_key() -> int:
	var now: StringName = station()
	if now == &"mend" or now == &"":
		return -1
	return pick_key(carried_keys(), now == &"relic", Rules.level_seed(Rules.level_seed(map_info.coord.x, map_info.coord.y), KEY_DEAL))


## The coloured keys the wizard carries (papers and the kept skeleton keys and relic unlocks are no
## price).
func carried_keys() -> Array[int]:
	var carried: Array[int] = []
	for c: int in player.keyring.all():
		if c >= 0 and c < Rules.KEY_RARITY.size():
			carried.append(c)
	return carried


## Which of the coloured keys `carried` a draw of `roll` (any int) takes: any of them alike, or for a
## relic's whereabouts (`relic`) weighted toward the rarer ones (RELIC_KEY_WEIGHT); -1 for none.
static func pick_key(carried: Array[int], relic: bool, roll: int) -> int:
	if carried.is_empty():
		return -1
	var keys: Array[int] = carried.duplicate()
	keys.sort()
	var total: int = 0
	for c: int in keys:
		total += RELIC_KEY_WEIGHT[c] if relic else 1
	var r: int = posmod(roll, total)
	for c: int in keys:
		r -= RELIC_KEY_WEIGHT[c] if relic else 1
		if r < 0:
			return c
	return keys[-1]


## Keys the third station asks for now: KEY_COST, or none for mending.
func keys_asked() -> int:
	return 0 if station() == &"mend" or station() == &"" else KEY_COST


func buy_mend() -> void:
	if used():
		return
	match station():
		&"mend":
			# Free: healing to full, and the utility spell held filled.
			player.health.health = player.health.max_health
			map_info.refill_utility()
			_spend($Mend as Node2D, [RisoPrint.EYE, RisoPrint.PINK])
		&"door":
			if not _pay(door_price(), true):
				return
			map_info.dig_way_on()
			_spend($Mend as Node2D, [RisoPrint.ACCENT, RisoPrint.BLUE])
		&"relic":
			if not _pay(relic_price(), true):
				return
			map_info.hint_relic()
			_spend($Mend as Node2D, [RisoPrint.ACCENT, RisoPrint.BLUE])
		&"skeleton":
			if not _pay(skeleton_price(), true):
				return
			map_info.lay_sold_skeleton()
			_spend($Mend as Node2D, [RisoPrint.EYE, RisoPrint.BLUE])


## At full health, the third station sells the whereabouts of the nearest relic not yet found or
## marked (see Relics), marked on the worlds map, unless it sells a door or a skeleton key.
func reads_relic() -> bool:
	return station() == &"relic"


## Shares (%) of shrines whose third station sells a skeleton key at full health instead of a
## relic's whereabouts: SKELETON_SALE, or SKELETON_SALE_HINTED while a relic already marked waits
## to be found. With no relic left to point to, it always does. Its price is SKELETON_PRICE times
## the level's deeper price.
const SKELETON_SALE: int = 30
const SKELETON_SALE_HINTED: int = 70
const SKELETON_PRICE: float = 2.0


## At full health, the third station sells a skeleton key: bought, one is laid on a floor
## somewhere in the level (MapInfo.lay_sold_skeleton), shown on the map.
func sells_skeleton() -> bool:
	return station() == &"skeleton"


## Whether the shrine in level `at` sells a skeleton key over a relic's whereabouts (at full
## health, with a relic left to point to), dealt by the level seed; `hinted` while a relic already
## marked waits to be found.
static func sells_skeleton_at(at: Vector2i, hinted: bool) -> bool:
	var chance: int = SKELETON_SALE_HINTED if hinted else SKELETON_SALE
	return Rules.level_seed(Rules.level_seed(at.x, at.y), 6100) % 100 < chance


func skeleton_price() -> int:
	return roundi(SKELETON_PRICE * float(Rules.deeper_price(depth())))


## The price in stars of which way the boss ahead lies: BOSS_PRICE times the level's deeper price.
const BOSS_PRICE: float = 1.0


## The boss ahead whose way this shrine could tell (Bosses.ahead): alive, met in a gate level (not
## the whale, which roams), and in an ordinary level; else &"".
func boss() -> StringName:
	if map_info == null or map_info.here == null or Worlds.is_side(map_info.coord):
		return &""
	var b: StringName = Bosses.ahead(map_info.coord.y)
	if b == &"" or b == &"whale" or map_info.run.bosses.has(b):
		return &""
	return b


## The share (%) of shrines in levels the labyrinth left with no way on whose third station, at full
## health, sells one (a door dug through to the level beyond, MapInfo.dig_way_on), over anything
## else; dealt by the level seed. Its price is DOOR_PRICE times the level's deeper price, and the
## door is then an ordinary way on, its toll and all.
const DOOR_SALE: int = 60
const DOOR_PRICE: float = 1.0
## Salt for the level seed when dealing the door sale.
const DOOR_SALE_DEAL: int = 6700


## Whether this level wants a way on: the labyrinth left it none (NextWorldDef.shut) and the run has
## not dug one (NextWorldDef.closed), in an ordinary level.
func door_wanted() -> bool:
	if map_info == null or map_info.here == null or Worlds.is_side(map_info.coord):
		return false
	return map_info.here.shut.has(MapInfo.Exit.DEEPER) and map_info.here.closed(MapInfo.Exit.DEEPER)


## At full health, the third station sells a way on: bought, a door appears at the spot kept for it
## (MapInfo.dig_way_on), leading on as any way on does.
func sells_door() -> bool:
	return station() == &"door"


## Whether the shrine in level `at` sells a way on where it wants one, dealt by the level seed.
static func sells_door_at(at: Vector2i) -> bool:
	return Rules.level_seed(Rules.level_seed(at.x, at.y), DOOR_SALE_DEAL) % 100 < DOOR_SALE


func door_price() -> int:
	return roundi(DOOR_PRICE * float(Rules.deeper_price(depth())))


## Whether it sells which way the boss ahead lies now: while that boss lives (boss), and until a
## shrine in this column has told it (told_way); at any health, spent or not.
func sells_way() -> bool:
	return boss() != &"" and told_way() == null


## Tell which way the boss ahead lies, for boss_price stars alone (no key): left, right or this
## column (MapInfo.hint_boss), shown on the worlds map and at the station. It does not spend the
## shrine.
func buy_way() -> void:
	if not sells_way() or player.coins.coins < boss_price():
		return
	player.collect(-boss_price())
	map_info.hint_boss(boss())
	map_info.save_run()
	RisoFx.burst(&"gain", ($Way as Node2D).global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.PINK, RisoPrint.NIGHT])


func boss_price() -> int:
	return roundi(BOSS_PRICE * float(Rules.deeper_price(depth())))


## The way this column's shrines told of the boss ahead (-1 left, 1 right, 0 this column), or null
## if none has.
func told_way() -> Variant:
	if map_info == null:
		return null
	var b: StringName = Bosses.ahead(map_info.coord.y) if not Worlds.is_side(map_info.coord) else &""
	for hint: Array in map_info.run.boss_hints.get(b, []):
		if int(hint[0]) == map_info.coord.x:
			return int(hint[1])
	return null


## The price in stars of what the third station offers now (0 for mending).
func station_price() -> int:
	match station():
		&"door":
			return door_price()
		&"relic":
			return relic_price()
		&"skeleton":
			return skeleton_price()
	return 0


## The move the relic it would point to holds, or &"".
func relic_move() -> StringName:
	var at: Variant = map_info.next_relic() if map_info != null else null
	return Relics.at(at) if at != null else &""


func relic_price() -> int:
	return Relics.hint_price(depth())


## Pay `cost` stars and, with `keyed`, the third station's keys asked (keys_asked: the one taken_key
## deals); nothing is paid unless all of it can be.
func _pay(cost: int, keyed: bool = false) -> bool:
	if player.coins.coins < cost:
		return false
	var key: int = taken_key() if keyed and keys_asked() > 0 else -1
	if keyed and keys_asked() > 0 and key < 0:
		return false
	player.collect(-cost)
	if key >= 0:
		player.keyring.spend(key)
	return true


func _spend(side: Node2D, inks: Array[int]) -> void:
	map_info.record().shrine_used = true
	map_info.save_run()
	RisoFx.burst(&"gain", side.global_position + Vector2(0, -40), Vector2.ZERO, inks)


## Only offer the interact prompt where there is something to do.
func _process(_delta: float) -> void:
	var spent: bool = used()
	$Boon/Interactable.available = not spent
	$Boon2/Interactable.available = not spent
	$Mend/Interactable.available = not spent and station() != &""
	$Redraw/Interactable.available = can_redraw()
	$Way/Interactable.available = sells_way()


func _ready() -> void:
	$Boon/Interactable.interacted.connect(buy_boon.bind(0))
	$Boon2/Interactable.interacted.connect(buy_boon.bind(1))
	$Mend/Interactable.interacted.connect(buy_mend)
	$Redraw/Interactable.interacted.connect(buy_redraw)
	$Way/Interactable.interacted.connect(buy_way)
