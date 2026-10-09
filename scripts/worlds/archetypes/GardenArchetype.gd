class_name GardenArchetype
extends Archetype
## The garden: the caves a run starts in, tunnels collapsed from the levels' own sample, gated by
## doors and switch gates in their corridors, with nothing added to an ordinary level's dressing.

## Its WFC sample: the tunnels (side worlds with no sample of their own use it too).
const SAMPLE: String = "res://wfc_images/levelSample3-spikes.png"


func _init() -> void:
	name = &"garden"
	sample = SAMPLE
