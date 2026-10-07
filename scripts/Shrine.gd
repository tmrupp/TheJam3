extends Node2D
class_name Shrine
## A level's shrine, near its deeper exit, across two cells. It offers three things; taking any
## one spends it:
## - two boons: the next tier of two different abilities (picked by the level seed, new ones
##   before upgrades), cheaper deeper;
## - mending: healing to full, dearer deeper; at full health, the whereabouts of the nearest
##   relic not yet found instead (see Relics), marked on the worlds map, or a skeleton key
##   (sells_skeleton), laid somewhere in the level for the wizard to find.
## Pay to learn. There is no menu: interact with the one you want.
## A spell learned in place of the one in the slot leaves the old spell in its niche, at its tier;
## interacting there takes it back free (leaving the newer one in turn), even once spent.

const BOONS: int = 2

@onready var player: Player = Stage.player()

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


func depth() -> int:
	return map_info.coord.y if map_info != null else 0


func used() -> bool:
	return map_info == null or bool(map_info.record().shrine_used)


func offers() -> Array[StringName]:
	if map_info == null:
		return []
	return Abilities.offers(Rules.level_seed(map_info.coord.x, map_info.coord.y), player, BOONS)


## The ability in niche `i` (0 or 1), or &"" when there is nothing left to offer there.
func offer(i: int = 0) -> StringName:
	var all: Array[StringName] = offers()
	return all[i] if i < all.size() else &""


func offer_tier(i: int = 0) -> int:
	return Abilities.tier(player, offer(i)) + 1


## Learning niche `i` would replace the spell in the slot.
func swap(i: int = 0) -> bool:
	return Abilities.is_swap(player, offer(i))


func offer_price(i: int = 0) -> int:
	return Abilities.price(depth(), offer_tier(i))


func heal_price() -> int:
	return Abilities.heal_price(depth())


func can_mend() -> bool:
	return player.health.health < player.health.max_health


func buy_boon(i: int = 0) -> void:
	if used():
		take_back(i)
		return
	var a: StringName = offer(i)
	if a == &"":
		return
	# A spell that replaces the one in the slot leaves the old one here, at its tier.
	var dropped: StringName = Abilities.spell(player) if swap(i) else &""
	var dropped_tier: int = Abilities.tier(player, dropped) if dropped != &"" else 0
	if not _pay(offer_price(i)):
		return
	Abilities.grant(player, a)
	if dropped != &"":
		map_info.record().left_spell = [dropped, dropped_tier, i]
	_spend(get_node("Boon" if i == 0 else "Boon2") as Node2D, [RisoPrint.ACCENT, RisoPrint.PINK])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare({&"wall_climb": &"climb"}.get(a, a))


## The spell left in niche `i` by a swap, as [spell, tier], or an empty array.
func left_spell(i: int) -> Array:
	var left: Array = map_info.record().left_spell if map_info != null else []
	return [StringName(left[0]), int(left[1])] if left.size() == 3 and int(left[2]) == i else []


## Take back the spell left in niche `i`, free and at its tier, leaving the one in the slot
## (if any) there in its place: a spent shrine still swaps.
func take_back(i: int) -> void:
	var left: Array = left_spell(i)
	if left.is_empty():
		return
	var held: StringName = Abilities.spell(player)
	var held_tier: int = Abilities.tier(player, held) if held != &"" else 0
	Abilities.set_tier(player, left[0], left[1])
	if held != &"":
		map_info.record().left_spell = [held, held_tier, i]
	else:
		map_info.record().left_spell = []
	map_info.save_run()
	RisoFx.burst(&"gain", (get_node("Boon" if i == 0 else "Boon2") as Node2D).global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(left[0])


## At full health (nothing to mend), the mending station sells the whereabouts of the nearest relic
## not yet found or marked instead (see Relics), marked on the worlds map, unless it sells a
## skeleton key (sells_skeleton).
func reads_relic() -> bool:
	return not can_mend() and map_info != null and map_info.next_relic() != null and not sells_skeleton()


## Shares (%) of shrines whose mending station sells a skeleton key at full health instead of a
## relic's whereabouts: SKELETON_SALE, or SKELETON_SALE_HINTED while a relic already marked waits
## to be found. With no relic left to point to, it always does. Its price is SKELETON_PRICE times
## the level's deeper price.
const SKELETON_SALE: int = 30
const SKELETON_SALE_HINTED: int = 70
const SKELETON_PRICE: float = 2.0


## At full health, the mending station sells a skeleton key: bought, one is laid on a floor
## somewhere in the level (MapInfo.lay_sold_skeleton), shown on the map.
func sells_skeleton() -> bool:
	if can_mend() or map_info == null:
		return false
	if map_info.next_relic() == null:
		return true
	return sells_skeleton_at(map_info.coord, not map_info.run.relic_hints.is_empty())


## Whether the shrine in level `at` sells a skeleton key over a relic's whereabouts (at full
## health, with a relic left to point to), dealt by the level seed; `hinted` while a relic already
## marked waits to be found.
static func sells_skeleton_at(at: Vector2i, hinted: bool) -> bool:
	var chance: int = SKELETON_SALE_HINTED if hinted else SKELETON_SALE
	return Rules.level_seed(Rules.level_seed(at.x, at.y), 6100) % 100 < chance


func skeleton_price() -> int:
	return roundi(SKELETON_PRICE * float(Rules.deeper_price(depth())))


## The move the relic it would point to holds, or &"".
func relic_move() -> StringName:
	var at: Variant = map_info.next_relic() if map_info != null else null
	return Relics.at(at) if at != null else &""


func relic_price() -> int:
	return Relics.hint_price(depth())


## The third station: mend while hurt, else a relic's whereabouts or a skeleton key.
func buy_mend() -> void:
	if used():
		return
	if can_mend():
		if not _pay(heal_price()):
			return
		player.health.health = player.health.max_health
		_spend($Mend as Node2D, [RisoPrint.EYE, RisoPrint.PINK])
	elif reads_relic():
		if not _pay(relic_price()):
			return
		map_info.hint_relic()
		_spend($Mend as Node2D, [RisoPrint.ACCENT, RisoPrint.BLUE])
	elif sells_skeleton():
		if not _pay(skeleton_price()):
			return
		map_info.lay_sold_skeleton()
		_spend($Mend as Node2D, [RisoPrint.EYE, RisoPrint.BLUE])


func _pay(cost: int) -> bool:
	if player.coins.coins < cost:
		return false
	player.collect(-cost)
	return true


func _spend(side: Node2D, inks: Array[int]) -> void:
	map_info.record().shrine_used = true
	map_info.save_run()
	RisoFx.burst(&"gain", side.global_position + Vector2(0, -40), Vector2.ZERO, inks)


## Only offer the interact prompt where there is something to do: an offer, or a left spell.
func _process(_delta: float) -> void:
	var spent: bool = used()
	$Boon/Interactable.available = not spent or not left_spell(0).is_empty()
	$Boon2/Interactable.available = not spent or not left_spell(1).is_empty()
	$Mend/Interactable.available = not spent and (can_mend() or reads_relic() or sells_skeleton())


func _ready() -> void:
	$Boon/Interactable.interacted.connect(buy_boon.bind(0))
	$Boon2/Interactable.interacted.connect(buy_boon.bind(1))
	$Mend/Interactable.interacted.connect(buy_mend)
