class_name Circuit
extends Structure
## The gondola's circuit a crags level laid (CragsArchetype.lay_circuit).

## The track's cells, bottom up.
var path: Array[Vector2i] = []
## Where on the path each station is.
var stops: Array = []
## Each station's gate's cell.
var gates: Array = []
## Each station's landing.
var inner: Array = []
## Which stations each tower's switch flips, a bit each (Stations.deal).
var masks: Array = []
## The tier each tower answers to.
var tiers: Array = []


## One laid, holding what it is first laid with.
static func make(path_: Array[Vector2i], stops_: Array, gates_: Array, inner_: Array) -> Circuit:
	var it: Circuit = Circuit.new()
	it.path = path_
	it.stops = stops_
	it.gates = gates_
	it.inner = inner_
	return it


## None: what a level holds, or is handed, where there is no such thing (is_empty).
static func none() -> Circuit:
	var it: Circuit = Circuit.new()
	it.laid = false
	return it
