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
## Exam papers are carried on the ring as keys are, taking a slot each: a "colour" from PAPER up,
## holding an ability that takes a slot (subjects) and its tier (paper), that no door takes. A paper is
## a spell known but not held: earned in the institute's classes (Timetable), handed back for a spell
## put out of its slot (MapInfo.put_back: at a lantern, a shrine, a lesson), and learned at a lantern
## (MapInfo.learn_paper). Grabbed, swapped, dropped and saved as any key is, and kept through a death.

const SKELETON: int = 99
## Where exam papers' codes start: PAPER, plus PAPER_SPELL for each place of the subject in
## subjects, plus the tier.
const PAPER: int = 1000
const PAPER_SPELL: int = 10


## What a paper may hold: every ability that takes a slot (Abilities.slot_of), in Abilities' order.
static func subjects() -> Array[StringName]:
	return Abilities.ids().filter(func(a: StringName) -> bool: return Abilities.slot_of(a) != &"")


## The code of an exam paper for ability `a` at `tier`.
static func paper(a: StringName, tier: int) -> int:
	return PAPER + subjects().find(a) * PAPER_SPELL + tier


## Whether `code` is an exam paper's, and the spell and tier it holds.
static func is_paper(code: int) -> bool:
	return code >= PAPER


static func paper_spell(code: int) -> StringName:
	@warning_ignore("integer_division")
	var i: int = (code - PAPER) / PAPER_SPELL
	var all: Array[StringName] = subjects()
	return all[i] if i >= 0 and i < all.size() else &""


static func paper_tier(code: int) -> int:
	return posmod(code - PAPER, PAPER_SPELL)

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


## Empty-handed: a new run.
func clear() -> void:
	_colored.clear()
	_skeletons = 0
