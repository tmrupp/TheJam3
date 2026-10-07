class_name KeyRing
extends Node
## The keys the wizard carries: a node on the player (`player.keyring`), as Coins and Health are.
## Keys are never used up: a carried key opens every door of its colour, in any level. Without the
## keyring perk the wizard carries one; each tier of it carries one more (Abilities). Grabbing a key
## with the ring full leaves the oldest where the new one was (MapInfo.key_taken). A key of a colour
## already carried is left where it lies.
## Skeleton keys (colour SKELETON) are rare and kept apart: each opens any one locked door
## (corridor or side door) whatever its colour, then crumbles. They are only used on purpose, by
## interacting with a door no carried key opens.

const SKELETON: int = 99

## The coloured keys carried, oldest first (the newest last).
var _colored: Array[int] = []
## Skeleton keys carried.
var _skeletons: int = 0


## How many coloured keys the wizard can carry.
func capacity() -> int:
	var player: Player = get_parent() as Player
	return 1 + (Abilities.tier(player, &"keyring") if player != null else 0)


## Every coloured key carried, oldest first (the newest last).
func all() -> Array[int]:
	return _colored.duplicate()


## The key grabbed last, or -1 for none.
func newest() -> int:
	return _colored[-1] if not _colored.is_empty() else -1


func has(color: int) -> bool:
	return _colored.has(color)


## Carry a newly grabbed key of `color`. Returns the colour left behind (the oldest, when the ring
## is full), or -1.
func take(color: int) -> int:
	_colored.append(color)
	return _colored.pop_front() if _colored.size() > capacity() else -1


## Carry exactly `keys` (oldest first); trimmed to the ring's capacity, oldest dropped.
func set_all(keys: Array) -> void:
	_colored.clear()
	for c: Variant in keys:
		if int(c) >= 0:
			_colored.append(int(c))
	while _colored.size() > capacity():
		_colored.pop_front()


func skeletons() -> int:
	return _skeletons


func set_skeletons(n: int) -> void:
	_skeletons = maxi(n, 0)


## Use up a skeleton key, if one is carried.
func spend_skeleton() -> bool:
	if _skeletons <= 0:
		return false
	_skeletons -= 1
	return true


## Empty-handed: a new run.
func clear() -> void:
	_colored.clear()
	_skeletons = 0
