# Where things used to live

An index of what has been taken out of the tree: finished plans, dead code, unused assets and
build products. Nothing here is lost: each entry names a commit that still holds it.

## Getting something back

- A file as it was: `git show <commit>:<path>` (or `git checkout <commit> -- <path>` to restore it).
- A file deleted by a commit: `git show <commit>^:<path>` (the commit's parent still has it).
- Where a name went: `git log -S '<name>' --oneline` finds the commits that added or removed it.
- Everything ever under a path: `git log --oneline -- <path>`.

## The cleanup of 2026-11-06

Everything below was still present on `game/deeper` at **`32fe6178dd`**, the commit this cleanup
was merged onto (`git show 32fe6178dd:<path>`).

### Plans retired

| What | Where it was | Why it went |
|---|---|---|
| The ten follow-ups to the architecture refactor | `docs/CLEANUP_PLAN.md` | All ten were done (commit `d569a4d`, 2026-10-07). It explained why `reach_from`, `best_of`, `_room_beside`, `Rules`, the art tables and the checked protocols are shaped as they are. |
| The character-selection checkpoint | `docs/mockups/wizard-replacements/IMPLEMENTATION.md` | The traveler costumes are built and the Fool is the only one left; the concept sheets and captures beside it stay. |
| The deeper plan's phase list and "What changes in the code" | `docs/DEEPER_PLAN.md`, sections "Phases" and "What changes in the code" | Built; replaced by a short "Status". |
| Groups 1, 2, 7, 8 and 9 of "Grouped for implementation" | `docs/DEEPER_PLAN.md` | Done (a way out at the start, exploration and gating, light and lanterns, the economy pass, small polish). |
| The regions plan's phase write-ups | `docs/REGIONS_PLAN.md` §8 | Built; condensed to one line a phase with what is still not done. The long write-ups record which layouts each phase re-pinned. |
| The climbing aid's numbers | `docs/REGIONS_PLAN.md` §4 and the bramble's section | The aid was removed in `48701250b1`. |

### Code

| What | Where it was | Notes |
|---|---|---|
| `Climb` (`hop_up`, `footholds`, `FALL`, `RELIC_UP`) | `scripts/level/Climb.gd` | Only `bramble_test` used it, to print how often the bramble's way on is climbed to: a traversability statistic, which the owner's rule rules out. `Reach.grow` lost its `down` parameter with it. |
| The code menu (`CodeMenu`) and the `Back` input action | `scripts/code_menu.gd`, `prefabs/code_menu.tscn`, a node in `prefabs/scenes/main.tscn`, `project.godot` | The jam build's arrow-code entry. Nothing opened it, but it still read input while hidden, and Back on an empty code unpaused the tree. `docs/PAIRED_PLAN.md` may want coded messages again; this is where the old entry screen lives. |
| The stand-in boss (`Boss`: a wisp twice the size, 10 hits shown as pips) | `scripts/bosses/Boss.gd`, `prefabs/boss.tscn`, the fallback in `Bosses.scene`, the BOSS row's prefab and art in `Placeables`, its branch in `MapInfo.slay_boss` | Every boss is built as its own prefab (`Bosses.SCENES`), so nothing was fought as the stand-in any more. |
| A quit button script | `scripts/Exit.gd` | Attached to nothing. |
| A scratch scene | `scenes/tom.tscn` | Opened by nothing. |
| A one-off probe | `tests/zz_probe_masonry.gd` | Counted the crags' exposed masonry; not a test. |
| `InkCanvas.set_bone` | `scripts/riso/InkCanvas.gd` | Bones are placed by `bone()` each print. |
| `menu.start_random`, `Bands.script_at` | `scripts/menu.gd`, `scripts/worlds/Bands.gd` | Unused (a blank world seed starts a random run through `start_game`; `Bands.archetype_at` gives a row's archetype). |
| `RisoWizard._sm`, `STEP_LIFT`, `ALL` | `scripts/riso/RisoWizard.gd` | The figure is bowed point by point by `_smv`; the gait is `RisoCostume.gait`. |
| `RisoShapes.xf` | `scripts/riso/RisoShapes.gd` | A transform times a polygon, written out where needed. |
| `RisoGlyph.MARK_R` | `scripts/riso/RisoGlyph.gd` | Documented the marks' size (about 24); now said in `RisoGlyph.draw`'s comment. |
| `RisoDecor.WEB_REACH` | `scripts/riso/RisoDecor.gd` | Cobwebs are spun without it. |
| `Crypts.FONT_REACH` | `scripts/level/Crypts.gd` | The font takes the nearest free floor within `FONT_FAR`, so the nearer limit did nothing. |
| `Timetable.any_class`, `master_of` | `scripts/level/Timetable.gd` | Unused. |
| `Abilities.spells`, `ActionTimer.resume`, `RockBug.riding`, `Wreck.afloat`, `Player.CLIMB_SPEED` | their scripts | Unused. |
| Commented-out code | `Player.gd` (the jam build's animation calls), `ParticleController.gd`, `code_menu.gd` | |

### Tests and captures

| What | Where it was | Why it went |
|---|---|---|
| A capture of the gate | `tests/capture_gate.gd` | It photographed the stand-in boss, which no gate level holds now that every boss is built; its other still (the bramble's sealed way on) is `capture_bramble`'s. |
| A capture of a fixed hyperspace lantern, garden foliage and the F7 equipment | `tests/capture_garden_equipment.gd` | A one-off review of a fix; the foliage is `capture_sway`'s and `capture_edges`'s, the panel `capture_panel`'s. |
| A review of key identities | `tests/capture_key_identity.gd` | A one-off review; keys and locks are in `capture_hud` and `capture_economy`. |
| Fresh lantern screenshots | `tests/capture_lantern_death.gd` | A one-off; the lantern lit, snuffed and unprotected is `capture_snuffer`'s, death `capture_death`'s. |
| Stills of a falling stalactite | `tests/capture_stalactite.gd` | `capture_castle` takes the same fall. |
| Each test's own `check`, game start and exit | 16 tests (`bird_detection`, `connect`, `gust_steering`, `hopper_contact`, `jump`, `music_loop`, `print_controls`, `relics_needed`, `riso_pin`, `riso_print`, `room`, `sky_art`, `spawn_balance`, `start_escape`, `watcher`, and `fog_styles`' start) | All on `TestKit` now; the generator tests use `build()` rather than the game scene. |
| Checks that the jam build's upgrade shop, pixel HUD and title art are gone, and two checks made twice | `tests/riso_print_test.gd` | Those parts went in 2026-09 and 2026-10. |
| Unused helpers: `wall_test.hold`, `_at` in `make_graveyard_sample` and `make_institute_sample` | those scripts | |

`capture_hex` (it no longer found the hex spell on a fresh wizard), `capture_tower_pieces`
(world 28's crag levels no longer hold a mending bowl) and `capture_lodestones` (its own `still`
clashed with `TestKit.still`, so it no longer parsed; now `photo`) were fixed rather than removed.

### Assets

| What | Where it was |
|---|---|
| 815 of the 816 input prompt tiles (only `tile_0087.png`, the interactable's, was used) | `input_prompts/` |
| 228 of the 231 jam tiles (only `tile_0027`, `tile_0111` and `tile_0146` were used) | `sprites/Tiles/` (with `Backgrounds/`, `Characters/`) |
| The jam's main menu placeholders | `menuPlaceholder/` |
| The jam's sprites and tilesets: `StarChart`, `TestCharacter`, `TestImage_dont_use_directly`, `backgroundjam3`, `big_boss_menu`, `map_image.aseprite`, `map_shard`, `mapart`, `mapshardart`, `spikesart`; `tilemap/Background1 (32x32)`, `TerrainJam3 (32x32)`, `TileSetGameJam3` | `sprites/` |
| Old WFC samples: `levelSample2`, `levelSample2_v2`, `levelSample3`, `levelSample4`, `floating_islands` (and its `.aseprite`), `map_image`, `pixil-frame-0`, `stripes`, `Sprite-0001`, `Sprite-0002` | `wfc_images/` (the samples in use are the ones the archetypes name) |
| Loose files at the root: `Sprite-0001.aseprite`, `Sprite-0002.aseprite`, `big_boss_menu` (a 4K PNG without its extension), and the backups `Terrain (32x32).png~`, `TerrainJam3 (32x32).png~`, `backgroundjam3.png~` | the root |

### Build products

| What | Where it was |
|---|---|
| The jam's exported build (2023-08-13): `TheJam3.exe`, `TheJam3.console.exe`, `TheJam3.pck` and its DLL, 127 MB | `builds/` |
| The extension's object files, link library and exports (`*.obj`, `*.lib`, `*.exp`), the SCons database and an unused `fast-wfc.lib` | `gdextension/src/`, `gdextension/demo/bin/`, `gdextension/` |
| Visual Studio's workspace state | `gdextension/.vs/` |

The extension's sources, `SConstruct` and the built `libgdexample` libraries the game loads stay.
`.gitignore` now keeps build products and Visual Studio state out.

## Earlier removals

Each commit below deleted what its row names; the files are at the commit's parent
(`git show <commit>^:<path>`).

| Commit | Date | What went |
|---|---|---|
| (the commit after `a9bd4fb`: `git show a9bd4fb:scripts/riso/props/WispArt.gd`) | 2026-11-11 | The wisp's body laid along the path its head had travelled (its trail, its four chains of 17 bones, its two veils and fading tail) and its turn round a teardrop fitted to the room ahead (`wisp_loop`, `_fit_loop`), for one teardrop on a spine of thirteen bones, whose tail reads its bend from a wake of headings and whose turn runs round a loop worked out once (`WispArt.turn_path`). |
| (`git log --diff-filter=D -- music/big_bossanova.wav`) | 2026-11-07 | The music as a WAV (`music/big_bossanova.wav`, 34 MB), kept as Ogg Vorbis since (`big_bossanova.ogg`). |
| `3ce63d4b38` | 2026-10-20 | The spider boss and its keep (`scripts/bosses/Spider*.gd`, `EggSac`, `WebShot`, `BroodWound`, `prefabs/spider.tscn`, `spider_test`), for the lodestone golem. |
| `6dd585d084` | 2026-10-19 | The institute's glyph seals (`GlyphSeal.gd`, `glyph_seal.tscn`, `GlyphSealArt.gd`). |
| `6d68f3c712` | 2026-10-17 | Lessons as trials and exam prizes (`TrialPiece`, `ExamPrize` and their art, `trials_test`), for exam papers. |
| `48701250b1` | 2026-10-14 | The climbing aid (`Climb.aid`, `climb_test`) and the crags' shutters (`Shutter.gd`, `shutter.tscn`). |
| `03e05c2e6c` | 2026-10-13 | The catacombs band (`CatacombsArchetype.gd`), for the institute. |
| `caf96576bd` | 2026-10-11 | The other travelers (cosmonaut, shaman: `character_styles_test`), the jam's test scenes (`NickTest`, `julia`, `tom_test`), `Cooldown`, `Diamond`, `ImageConverter`, `WaveFunctionCollapseGenerate`, `newGame`, the old main menu. |
| `afda2567e4` | 2026-10-10 | Boss arenas (`scripts/worlds/Arena.gd`): bosses fight in their gate levels. |
| `d1289d1109` | 2026-10-09 | `docs/TOM_THOUGHTS.md`: the owner's notes moved to the Google Doc. |
| `cefb2fa437` | 2026-10-05 | The Fourier and Rounded art paths and the print-off path (`Fourier*.gd`, `Rounded*.gd`, `DashTrail*`, `Background.gd`, `Keys.gd`, `docs/FOURIER_INTEGRATION.md`, `docs/ROUNDED_ART_DIRECTION.md`, `docs/plans/`). |
| `9e7c3e2e61` | 2026-10-04 | The Fourier tests and benchmark. |
| `af3af6612e` | 2026-09-30 | Astral projection points and map shards (`astral_projection_point.gd`, `map_shard.gd`). |
| `9f258593d3` | 2026-09-30 | `StartGame.gd`, for the start menu. |
| `b080f28cbe` | 2026-09-30 | The jam's upgrade menu and shop (`Upgrade*.gd`, `upgrade_menu`, `WallClimb.gd`, `DoubleJump`), for shrines and tiered abilities. |
| `81ae343358` | 2026-09-30 | The jam's goal and backtracking (`goal.gd`, `respawn.gd`), for levels by (seed, depth). |
