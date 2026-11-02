extends TestKit
## A region's title card (RisoTransition.title, MapInfo._title_region): a run opens on the garden's;
## going on within a region shows none; crossing into another region shows that one's.
## godot --headless --path . --script res://tests/region_title_test.gd


func run() -> void:
	if not needs([&"cemetery"]):
		finish()
		return
	await boot()
	var card: RisoTransition = RisoTransition.instance
	check(card != null, "the transition is there")
	check(info.region == &"garden", "a run starts in the garden")
	check(not RisoPrint.is_on() or (card.titling() and card.title_text == "The Garden"), "and opens on its title card")
	card.title_age = -1.0
	info.debug = true
	await _go(Vector2i(28, NextWorldDef.band_row(&"garden", 1)))
	check(info.region == &"garden" and not card.titling(), "going on within the garden shows none")
	await _go(Vector2i(28, NextWorldDef.band_row(&"cemetery", 0)))
	check(info.region == &"cemetery", "crossing into the cemetery")
	check(not RisoPrint.is_on() or (card.titling() and card.title_text == "The Cemetery"), "shows its title card")
	var ended: bool = await until(func() -> bool: return not card.titling(), 8000)
	check(ended, "which goes after a moment")
	RunState.delete_save()
	finish()


## Travel straight to `at` (a debug run's travel) and wait for it to be laid out.
func _go(at: Vector2i) -> void:
	info.debug_travel(at)
	await process_frame
	await until(func() -> bool: return info.world != null and not info.travelling and info.coord == at, 20000)
