class_name Keys
extends RefCounted
## The codes of the keys that are not a colour, and of exam papers, apart from the ring that carries
## them (KeyRing, a node on the wizard, has them under the same names): the generator lays a
## skeleton key or a paper by its code without the wizard's scene being loaded
## (docs/CODE_REVIEW.md 2.1). What each is, see KeyRing.

## A skeleton key, a relic unlock and a seed: "colours" past the key colours (Rules.KEY_COLOR_COUNT).
const SKELETON: int = 99
const UNLOCK: int = 98
const SEED: int = 97
## The most seeds carried at once.
const SEEDS_MOST: int = 1
## Where exam papers' codes start: PAPER, plus PAPER_SPELL for each place of the subject in
## subjects, plus the tier.
const PAPER: int = 1000
const PAPER_SPELL: int = 10
## A stolen paper's code is its paper's plus this (tiers run below it).
const STOLEN: int = 5


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
	return posmod(code - PAPER, PAPER_SPELL) % STOLEN


## Whether exam paper `code` is stolen, and the stolen paper of the same spell and tier.
static func is_stolen(code: int) -> bool:
	return is_paper(code) and posmod(code - PAPER, PAPER_SPELL) >= STOLEN


static func stolen(code: int) -> int:
	return code if is_stolen(code) or not is_paper(code) else code + STOLEN
