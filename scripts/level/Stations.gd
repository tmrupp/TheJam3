class_name Stations
extends RefCounted
## The crags' tower puzzle, as logic alone (docs/REGIONS_PLAN.md §7, "The tower puzzle"): a level's
## gondola stations, one to each tier of the cliff, bottom (0) to top, each on or off (a bit of a
## mask), and its towers, each standing on a tier and flipping a set of stations (its own mask).
## The wizard in a tier can flip a tower standing there, unless it is the tower flipped last (a tower
## is locked until another is flipped), and can ride the gondola from their tier's station to
## another's when both are on and no two stations in a row between them are off (the car runs a
## stretch only if one of its ends is on). Nothing here draws from any RNG: the sets are dealt by
## hashing the level seed.
##
## No one is stranded for good: the level loading again (leaving it, or dying) lifts the lock, so
## every flip can be undone, and every ride can be ridden back. Taken that way (a state being the
## stations on and the tier, the lock set aside) the moves go both ways, so what can be reached from
## a state is all of its part of the whole, and if the way up and the way down lie in the part the
## starts are in, every state reached from there can still reach both ends.

## How many deals are tried before the best found is kept, and the salt for the level seed.
const DEAL_TRIES: int = 1000
const DEAL: int = 6620
## The fewest flips a way up or down is wanted to take (when a deal allows it), and the most a
## deal may want before it is passed over for a shorter one.
const FLIPS_LEAST: int = 3
const FLIPS_MOST: int = 9
## A tower takes each station it may into its set by one chance in TAKE (before the sets are evened
## out, see _sets): the fewer each flips, the more the car's way is worked for.
const TAKE: int = 3


## Whether the car carries the wizard from tier `from` to tier `to` with stations `mask` on: both
## on, and no two stations in a row between them off.
static func rides(mask: int, from: int, to: int) -> bool:
	if from == to or mask & (1 << from) == 0 or mask & (1 << to) == 0:
		return false
	var lo: int = mini(from, to)
	var hi: int = maxi(from, to)
	for i: int in range(lo, hi):
		if mask & (1 << i) == 0 and mask & (1 << (i + 1)) == 0:
			return false
	return true


## Where the car can take the wizard, for `n` stations: for each mask and tier (mask * n + tier), a
## bit for each tier it rides to (rides).
static func ride_table(n: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize((1 << n) * n)
	for mask: int in range(1 << n):
		for from: int in range(n):
			var bits: int = 0
			for to: int in range(n):
				if rides(mask, from, to):
					bits |= 1 << to
			out[mask * n + from] = bits
	return out


## The towers standing on each of `n` tiers, from the towers' `tiers`.
static func _by_tier(n: int, tiers: Array[int]) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for t: int in range(n):
		out.append(PackedInt32Array())
	for j: int in range(tiers.size()):
		out[tiers[j]].append(j)
	return out


## The fewest flips that take the wizard from tier `start` with stations `mask` on (no tower flipped
## yet, the lock kept: no leaving the level to lift it) to tier `goal`, among `n` stations and the
## towers standing on `tiers` flipping `masks`: the towers flipped, in order ([] if the wizard is
## there already, or can ride there at once), or null if it cannot be done. `table` is ride_table(n),
## worked out here if not given.
static func way(n: int, tiers: Array[int], masks: Array[int], mask: int, start: int, goal: int, table: PackedInt32Array = PackedInt32Array()) -> Variant:
	if table.is_empty():
		table = ride_table(n)
	var k: int = tiers.size()
	var by_tier: Array[PackedInt32Array] = _by_tier(n, tiers)
	var total: int = (1 << n) * n * (k + 1)
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(total)
	parent.fill(-2)
	var flip: PackedInt32Array = PackedInt32Array()
	flip.resize(total)
	var from: int = _id(mask, start, -1, n, k)
	parent[from] = -1
	flip[from] = -1
	var queue: PackedInt32Array = PackedInt32Array([from])
	var head: int = 0
	while head < queue.size():
		var id: int = queue[head]
		head += 1
		var last: int = id % (k + 1) - 1
		@warning_ignore("integer_division")
		var rest: int = id / (k + 1)
		var tier: int = rest % n
		@warning_ignore("integer_division")
		var m: int = rest / n
		if tier == goal:
			var out: Array[int] = []
			var at: int = id
			while parent[at] >= 0:
				if flip[at] >= 0:
					out.push_front(flip[at])
				at = parent[at]
			return out
		for j: int in by_tier[tier]:
			if j == last:
				continue
			var nid: int = _id(m ^ masks[j], tier, j, n, k)
			if parent[nid] == -2:
				parent[nid] = id
				flip[nid] = j
				queue.append(nid)
		var bits: int = table[m * n + tier]
		for t: int in range(n):
			if bits & (1 << t) == 0:
				continue
			var nid: int = _id(m, t, last, n, k)
			if parent[nid] == -2:
				parent[nid] = id
				flip[nid] = -1
				queue.append(nid)
	return null


## What can be reached from tier `start` with stations `mask` on, the lock set aside (see the class
## description): a byte for each mask and tier (mask * n + tier), 1 if reached.
static func reach(n: int, tiers: Array[int], masks: Array[int], mask: int, start: int, table: PackedInt32Array = PackedInt32Array()) -> PackedByteArray:
	if table.is_empty():
		table = ride_table(n)
	var by_tier: Array[PackedInt32Array] = _by_tier(n, tiers)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize((1 << n) * n)
	var from: int = mask * n + start
	seen[from] = 1
	var queue: PackedInt32Array = PackedInt32Array([from])
	var head: int = 0
	while head < queue.size():
		var id: int = queue[head]
		head += 1
		var tier: int = id % n
		@warning_ignore("integer_division")
		var m: int = id / n
		for j: int in by_tier[tier]:
			var nid: int = (m ^ masks[j]) * n + tier
			if seen[nid] == 0:
				seen[nid] = 1
				queue.append(nid)
		var bits: int = table[id]
		for t: int in range(n):
			if bits & (1 << t) != 0 and seen[m * n + t] == 0:
				seen[m * n + t] = 1
				queue.append(m * n + t)
	return seen


## Whether some flips from the bottom tier with only its station on leave every station on (the
## lock set aside: leaving the level lifts it).
static func all_on_reached(n: int, tiers: Array[int], masks: Array[int], table: PackedInt32Array = PackedInt32Array()) -> bool:
	var seen: PackedByteArray = reach(n, tiers, masks, 1, 0, table)
	var all: int = (1 << n) - 1
	for t: int in range(n):
		if seen[all * n + t] != 0:
			return true
	return false


## Deal the towers' sets of stations for a level of `n` stations with towers on `tiers` (see the
## class description), hashing `level_seed`: each tower flips a set dealt anew each try (_sets),
## never none and never its own tier's station (flipping that off would leave the wizard no way to
## board), so that flipping every tower once turns the whole line on from only the bottom on.
## A deal passes when, from the bottom tier with only its station on, the top tier with only its
## station on and every whole line on are reached (with the lock set aside), as is each tier in
## `side_starts` (entered from the side with only its station on), and there is a way up and a way
## down keeping the lock (way), with different tower sequences, of at most FLIPS_MOST flips. So no
## one is ever stranded (see the class description). Of the deals that pass, the first whose ways
## up and down both take FLIPS_LEAST flips or more, one of them going back to a tower flipped
## already (returns), is kept; else the best of them by those two; and if none passes, plain. (Flipping
## every tower once turns the whole line on, but that is the end, not the way: the order the
## towers are reached in, and the returns, are the puzzle.)
static func deal(n: int, tiers: Array[int], level_seed: int, side_starts: Array[int] = []) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	var k: int = tiers.size()
	var table: PackedInt32Array = ride_table(n)
	var all: int = (1 << n) - 1
	var top: int = n - 1
	var passed: bool = false
	for attempt: int in range(DEAL_TRIES):
		var masks: Array[int] = _sets(n, tiers, level_seed, attempt)
		if masks.is_empty():
			continue
		if best.is_empty():
			best = masks
		var seen: PackedByteArray = reach(n, tiers, masks, 1, 0, table)
		if seen[(1 << top) * n + top] == 0:
			continue
		var whole: bool = false
		for t: int in range(n):
			whole = whole or seen[all * n + t] != 0
		if not whole or side_starts.any(func(t: int) -> bool: return seen[(1 << t) * n + t] == 0):
			continue
		var up: Variant = way(n, tiers, masks, 1, 0, top, table)
		if up == null or (up as Array).size() > FLIPS_MOST:
			continue
		var down: Variant = way(n, tiers, masks, 1 << top, top, 0, table)
		if down == null or up == down or (down as Array).size() > FLIPS_MOST:
			continue
		# Worth more: ways long enough to be worked out, and one that sends the wizard back to a tower
		# they flipped already.
		var flips: int = mini(mini((up as Array).size(), (down as Array).size()), FLIPS_LEAST)
		var score: int = flips + (FLIPS_LEAST + 1 if returns(up) or returns(down) else 0)
		passed = true
		if score > best_score:
			best_score = score
			best = masks
		if score >= FLIPS_LEAST * 2 + 1:
			break
	if not passed:
		return plain(n, tiers)
	return best


## The sets of the last resort, when no deal passes: each tower flips every station but its own
## tier's. Flipping one in the bottom (or top) tier turns the whole line on, so the ways up and down
## are a flip each, by different towers, as long as the bottom and top tiers have a tower
## (CragsArchetype.build_towers sees to it).
static func plain(n: int, tiers: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for t: int in tiers:
		out.append(((1 << n) - 1) & ~(1 << t))
	return out


## Whether way `w` (towers flipped, in order; null for none) flips some tower more than once: the
## wizard has to go back to it.
static func returns(w: Variant) -> bool:
	if w == null:
		return false
	var seen: Dictionary = {}
	for j: int in w:
		if seen.has(j):
			return true
		seen[j] = true
	return false


## The towers' sets for try `attempt` (see deal), or [] if one came out empty: each station but the
## bottom one is flipped by an odd number of the towers not standing on its tier, the bottom one by
## an even number, each tower taking each station by a hashed chance (TAKE) and one of them evened
## out last.
## (Random sets would seldom add up to the whole line, which a line of many stations wants towers
## for most of its stations to reach by chance.)
static func _sets(n: int, tiers: Array[int], level_seed: int, attempt: int) -> Array[int]:
	var k: int = tiers.size()
	var masks: Array[int] = []
	masks.resize(k)
	masks.fill(0)
	for b: int in range(n):
		var able: Array[int] = []
		for j: int in range(k):
			if tiers[j] != b:
				able.append(j)
		if able.is_empty():
			continue
		var count: int = 0
		for j: int in able:
			if posmod(Rules.level_seed(level_seed, DEAL + attempt * 131 + b * 17 + j * 1009), TAKE) == 0:
				masks[j] |= 1 << b
				count += 1
		var want_odd: bool = b != 0
		if (count % 2 == 1) != want_odd:
			var fix: int = able[posmod(Rules.level_seed(level_seed, DEAL + attempt * 131 + b * 17 + 7), able.size())]
			masks[fix] ^= 1 << b
	# A tower left with none takes a station it may from another tower that has it, so every station
	# is still flipped as many times, odd or even, as it was.
	for j: int in range(k):
		if masks[j] != 0:
			continue
		for b: int in range(n):
			if tiers[j] == b:
				continue
			var giver: int = -1
			for o: int in range(k):
				if o != j and masks[o] & (1 << b) != 0 and masks[o] != (1 << b):
					giver = o
			if giver >= 0:
				masks[giver] ^= 1 << b
				masks[j] |= 1 << b
				break
	if masks.any(func(m: int) -> bool: return m == 0):
		return []
	return masks


## A state's number: stations `mask` on, the wizard on tier `tier`, tower `last` flipped last (-1
## for none), among `n` stations and `k` towers.
static func _id(mask: int, tier: int, last: int, n: int, k: int) -> int:
	return (mask * n + tier) * (k + 1) + last + 1
