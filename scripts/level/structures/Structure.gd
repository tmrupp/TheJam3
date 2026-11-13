class_name Structure
extends RefCounted
## Something a level's layout built and keeps on the level for the game and the tests to read (a
## crypt, a hall, a tower, a vault...; docs/CODE_REVIEW.md 2.3): a class of its own for each kind,
## with a field for each thing it holds, so a field mistyped fails as the script is read, not as a
## level is laid out. Each kind extends this.

## No cell: what a field holding a cell says when there is none.
const NONE: Vector2i = Vector2i(-1, -1)

## Whether it has been laid: false for the one a level keeps before (or without) laying it (the
## bramble's shaft, the golem's hall, the gondola's circuit).
var laid: bool = true


## Whether there is none (see laid): as an empty dictionary once said so.
func is_empty() -> bool:
	return not laid


## Its fields, by name: for comparing two of them, or writing one out.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[prop["name"]] = get(prop["name"])
	return out


## Whether two lists of structures hold the same, one for one (their fields alike): two levels'
## vaults, say, laid out from one seed. (`==` on two of them asks only whether they are the one.)
static func alike(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if (a[i] as Structure).to_dict() != (b[i] as Structure).to_dict():
			return false
	return true
