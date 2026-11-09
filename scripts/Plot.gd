extends Area2D
class_name Plot
## A garden plot (GardenArchetype.finish): a bed of turned earth on a floor, one to a garden level.
## Carrying a seed (KeyRing.SEED, from a seed pod, SeedPod), the wizard plants it here with Discover;
## then it grows while they are away, and the further they go before coming back, the more it
## bears (RunState.plants keeps how far: the furthest place reached from here since it was planted,
## counted in places across and up or down, away). Back again, a grown plant is picked with Discover
## for its reward, by how far they went (TIERS): a star cluster, a skeleton key, or, furthest, a
## hyperspace door that stands where the plant grew for the rest of the run (free to go through:
## the plant paid for it), unless the level has a hyperspace door already (then a skeleton key).
## Picked, the plot is bare again for another seed; one that grew a door is the door's.

## How far away (places) the wizard must have gone since planting for the plant to bear each
## reward: a star cluster, a skeleton key, a hyperspace door. Not gone at all, it is a sprout still.
const TIERS: Array[int] = [1, 4, 8]

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


## How far apart places `a` and `b` are, for a plant's growth: across plus up or down, a side
## world counted as the level its door is in.
static func apart(a: Vector2i, b: Vector2i) -> int:
	var p: Vector2i = Worlds.origin_of(a) if Worlds.is_side(a) else a
	var q: Vector2i = Worlds.origin_of(b) if Worlds.is_side(b) else b
	return absi(p.x - q.x) + absi(p.y - q.y)


## What a plant grown that far (places) bears: 0 nothing yet (a sprout), 1 stars, 2 a skeleton key,
## 3 a hyperspace door (TIERS).
static func tier_of(furthest: int) -> int:
	var tier: int = 0
	for need: int in TIERS:
		if furthest >= need:
			tier += 1
	return tier


## This plot's plant ({"furthest", "door"}, see RunState.plants), or {} while it is bare.
func plant() -> Dictionary:
	if map_info == null or map_info.run == null:
		return {}
	return map_info.run.plants.get(map_info.coord, {})


## Whether a plant grows here (or grew a door).
func planted() -> bool:
	return not plant().is_empty()


## Whether its plant became a hyperspace door.
func door() -> bool:
	return bool(plant().get("door", false))


## What its plant bears now (tier_of), 0 when bare or a door.
func tier() -> int:
	var p: Dictionary = plant()
	if p.is_empty() or door():
		return 0
	return Plot.tier_of(int(p.get("furthest", 0)))


## Whether the wizard can plant here now (a seed carried, the plot bare).
func can_plant() -> bool:
	var player: Player = Stage.player()
	return not planted() and player != null and player.keyring.seeds() > 0


## Whether its plant can be picked (grown, not a door).
func can_pick() -> bool:
	return tier() > 0


func use() -> void:
	if map_info == null:
		return
	if can_pick():
		map_info.pick_plant(self)
	elif can_plant():
		map_info.plant_seed(self)


func _process(_delta: float) -> void:
	$Interactable.available = can_plant() or can_pick()


func _ready() -> void:
	$Interactable.interacted.connect(use)
