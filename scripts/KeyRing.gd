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
## Relic unlocks (colour UNLOCK) are dropped by bosses (MapInfo.boss_slain) and kept apart as skeleton
## keys are, trailing the wizard as keys do: a relic of a move not yet known cannot be taken without
## one, and taking it uses one up (Relic.take). A relic of a move already known (its next tier) needs
## none. No door takes them.
## Seeds (colour SEED) are dropped by the garden's seed pods (SeedPod) and kept apart as relic
## unlocks are, trailing the wizard; at most SEEDS_MOST are carried, a seed met with the pocket full
## left where it lies. One is planted at a garden plot (Plot) and used up so.
## Exam papers are carried on the ring as keys are, taking a slot each: a "colour" from PAPER up,
## holding an ability that takes a slot (subjects) and its tier (paper), that no door takes. A paper is
## a spell known but not held: earned in the institute's classes (Timetable), handed back for a spell
## put out of its slot (MapInfo.put_back: at a lantern, a shrine, a lesson), and learned at a lantern
## (MapInfo.learn_paper). Grabbed, swapped, dropped and saved as any key is, and kept through a death.
## A paper lifted off a lectern or left by a beaten master is stolen (stolen): while the wizard
## carries it, the institute's scholars turn on them (MapInfo.wizard_belongs). Learned, it is theirs.

const SKELETON: int = Keys.SKELETON
const UNLOCK: int = Keys.UNLOCK
const SEED: int = Keys.SEED
## The most seeds carried at once.
const SEEDS_MOST: int = Keys.SEEDS_MOST
## Where exam papers' codes start, how they are packed and what marks a stolen one (see Keys).
const PAPER: int = Keys.PAPER
const PAPER_SPELL: int = Keys.PAPER_SPELL
const STOLEN: int = Keys.STOLEN


## The papers' codes read and written (Keys has them, scene-free; these are the same by their old
## names).
static func subjects() -> Array[StringName]:
	return Keys.subjects()


static func paper(a: StringName, tier: int) -> int:
	return Keys.paper(a, tier)


static func is_paper(code: int) -> bool:
	return Keys.is_paper(code)


static func paper_spell(code: int) -> StringName:
	return Keys.paper_spell(code)


static func paper_tier(code: int) -> int:
	return Keys.paper_tier(code)


static func is_stolen(code: int) -> bool:
	return Keys.is_stolen(code)


static func stolen(code: int) -> int:
	return Keys.stolen(code)

## The coloured keys carried, oldest first (the newest last).
var _colored: Array[int] = []
## Skeleton keys carried.
var _skeletons: int = 0
## Relic unlocks carried.
var _unlocks: int = 0
## Seeds carried.
var _seeds: int = 0


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


## The exam papers carried, oldest first.
func papers() -> Array[int]:
	return _colored.filter(func(c: int) -> bool: return is_paper(c))


## Exam paper (or key) `code` carried changed for `to`, in its place on the ring (a paper graded up).
func replace(code: int, to: int) -> void:
	var k: int = _colored.find(code)
	if k >= 0:
		_colored[k] = to


## Give up exam paper (or key) `code`, if carried.
func spend(code: int) -> void:
	_colored.erase(code)


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


func unlocks() -> int:
	return _unlocks


func set_unlocks(n: int) -> void:
	_unlocks = maxi(n, 0)


## Use up a relic unlock, if one is carried.
func spend_unlock() -> bool:
	if _unlocks <= 0:
		return false
	_unlocks -= 1
	return true


func seeds() -> int:
	return _seeds


func set_seeds(n: int) -> void:
	_seeds = clampi(n, 0, SEEDS_MOST)


## Use up a seed (planted), if one is carried.
func spend_seed() -> bool:
	if _seeds <= 0:
		return false
	_seeds -= 1
	return true


## Empty-handed: a new run.
func clear() -> void:
	_colored.clear()
	_skeletons = 0
	_unlocks = 0
	_seeds = 0
