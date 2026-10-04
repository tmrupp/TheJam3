class_name KeyRing
extends RefCounted
## The keys the wizard carries. Keys are never used up: a carried key opens every door of its
## colour, in any level. Without the keyring perk the wizard carries one; each tier of it carries one
## more (Abilities). The newest key is the player's "carried_key" meta, the older ones on the ring
## are "spare_keys" (oldest first). Grabbing a key with the ring full leaves the oldest where the new
## one was (MapInfo.key_taken). A key of a colour already carried is left where it lies.
## Skeleton keys (colour SKELETON) are rare and kept apart, counted in "skeleton_keys": each opens
## any one locked door (corridor or side door) whatever its colour, then crumbles. They are only
## used on purpose, by interacting with a door no carried key opens.

const SKELETON: int = 99


## How many coloured keys the wizard can carry.
static func capacity(player: Player) -> int:
	return 1 + Abilities.tier(player, &"keyring")


## Every coloured key carried, oldest first (the newest last).
static func all(player: Player) -> Array[int]:
	var out: Array[int] = []
	for c: int in player.get_meta(&"spare_keys", []):
		out.append(c)
	if player.has_meta(&"carried_key"):
		out.append(int(player.get_meta(&"carried_key")))
	return out


static func has(player: Player, color: int) -> bool:
	return all(player).has(color)


## Carry a newly grabbed key of `color`. Returns the colour left behind (the oldest, when the ring
## is full), or -1.
static func take(player: Player, color: int) -> int:
	var keys: Array[int] = all(player)
	keys.append(color)
	var dropped: int = -1
	if keys.size() > capacity(player):
		dropped = keys.pop_front()
	_store(player, keys)
	return dropped


## Carry exactly `keys` (oldest first); trimmed to the ring's capacity, oldest dropped.
static func set_all(player: Player, keys: Array) -> void:
	var out: Array[int] = []
	for c: Variant in keys:
		if int(c) >= 0:
			out.append(int(c))
	while out.size() > capacity(player):
		out.pop_front()
	_store(player, out)


static func _store(player: Player, keys: Array[int]) -> void:
	if keys.is_empty():
		if player.has_meta(&"carried_key"):
			player.remove_meta(&"carried_key")
	else:
		player.set_meta(&"carried_key", keys[keys.size() - 1])
	var spare: Array[int] = keys.slice(0, maxi(0, keys.size() - 1))
	if spare.is_empty():
		if player.has_meta(&"spare_keys"):
			player.remove_meta(&"spare_keys")
	else:
		player.set_meta(&"spare_keys", spare)


static func skeletons(player: Player) -> int:
	return int(player.get_meta(&"skeleton_keys", 0))


static func set_skeletons(player: Player, n: int) -> void:
	if n > 0:
		player.set_meta(&"skeleton_keys", n)
	elif player.has_meta(&"skeleton_keys"):
		player.remove_meta(&"skeleton_keys")


## Use up a skeleton key, if one is carried.
static func spend_skeleton(player: Player) -> bool:
	var n: int = skeletons(player)
	if n <= 0:
		return false
	set_skeletons(player, n - 1)
	return true


## Empty-handed: a new run.
static func clear(player: Player) -> void:
	_store(player, [] as Array[int])
	set_skeletons(player, 0)
