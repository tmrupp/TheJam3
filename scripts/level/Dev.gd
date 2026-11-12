class_name Dev
extends RefCounted
## What kind of game this is, apart from the scene (MapInfo.debug, demo_build, demo_dev and
## dev_tools are these under their old names): a debug run, a demo build, and whether the
## developer's tools are at hand. The rules and the generator ask here, so they need not load the
## game's session to know (docs/CODE_REVIEW.md 2.1).

## Debug runs (from the start menu): every exit is generated right by the spawn, and the run
## starts with MapInfo.DEBUG_STARS. Saved with the run and shown in the HUD.
static var debug: bool = false
## Whether this is a demo build: an export with the "demo" feature (an export preset's custom
## feature), which also plays the demo's band layout (Bands.DEMO). Tests set it to try one.
static var demo_build: bool = OS.has_feature("demo")
## Whether this is a demo build kept for testing the demo: an export with the "demo_dev" feature as
## well as "demo" (the "Windows Demo (dev tools)" preset, into builds/demo-dev). It plays the demo
## all the same, with the developer's tools left in. Tests set it to try one.
static var demo_dev: bool = OS.has_feature("demo_dev")


## Whether the developer's tools are at hand: the start menu's debug toggle (debug runs), the F7
## panel and F8's realms (RisoPrint), and going back a level at a key (Debug-Back). A demo build has
## none of them, so its players get the game alone, on Normal (Difficulty.DEMO_DEFAULT); a demo
## build for testing (demo_dev) keeps them.
static func dev_tools() -> bool:
	return not demo_build or demo_dev
