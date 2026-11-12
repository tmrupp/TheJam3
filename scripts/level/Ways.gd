class_name Ways
extends RefCounted
## A level's ways out, named apart from the scene (MapInfo.Exit is this same list under its old
## name): the rules, the generator and the worlds' definitions speak of them without the game's
## session being loaded (docs/CODE_REVIEW.md 2.1).

## A level's ways out. Deeper and back move along the seed's column; left and right step to the
## neighbouring seed at the same depth, as if a run had started there; a level a side world leads
## into has an ordinary way up as well (RETURN). Where each leads is up to the place's definition
## (NextWorldDef.lead); doors into side worlds are numbered from Worlds.DOOR_BASE.
enum Exit { DEEPER, BACK, LEFT, RIGHT, RETURN }
