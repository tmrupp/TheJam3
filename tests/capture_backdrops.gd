extends TestKit
## The backdrop of each band as the game shows it (RisoBackground): a level of each band in the
## layout, the wizard where they arrive, the whole window at the game's own zoom
## (backdrop_<band>.png) and drawn back to twice as far, so more of the sheet behind the rock shows
## (backdrop_<band>_far.png), and that again with the dark out of the wizard's sight turned off
## (backdrop_<band>_open.png: in play the backdrop shows only where the wizard sees).
## godot --path . --windowed --resolution 1280x720 --screen 1 --script res://tests/capture_backdrops.gd

## The world the levels are taken from, and how far the far still draws back.
const WORLD: int = 28
const FAR: float = 0.5


func run() -> void:
	window()
	await boot(WORLD)
	var camera: Camera2D = Stage.camera()
	var base: Vector2 = camera.zoom
	for band: StringName in NextWorldDef.archetype_names():
		if Bands.rows_of(band) <= 0:
			continue
		await go(Vector2i(WORLD, NextWorldDef.band_row(band, mini(1, Bands.rows_of(band) - 1))))
		await settle(40)
		save_still("backdrop_%s.png" % band)
		camera.zoom = base * FAR
		await settle(20)
		save_still("backdrop_%s_far.png" % band)
		RisoLight.by_sight = false
		await settle(20)
		save_still("backdrop_%s_open.png" % band)
		RisoLight.by_sight = true
		camera.zoom = base
	finish()
