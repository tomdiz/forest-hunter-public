# Forest Hunter

A one-level, isometric 3D game built in [Xogot](https://xogot.com) (Godot 4.7) as a learning project.
A hunter follows a river through a pine forest, past a log cabin and its campfire, hunting an evil stag
with glowing red eyes. The stag hides, peeks, stalks, charges and retreats. Shoot it five times to win.
Lose all three hearts and it's game over.

This is a private, personal project. The assets are third-party packs, so do not publish or redistribute the repo.

## Game design

The full design is a single page: **[docs/game-design.html](docs/game-design.html)**.

It covers the map, controls, game logic, the assets in use, the scene tree, the build order and what is still
to do. Open it in a browser. GitHub shows HTML files as source, so clone the repo or download the file to view it.
It is drawn from the real level data, so keep it in sync when the game changes.

## Run it

1. Open this folder as a project in Xogot (Godot 4.7, Forward+ renderer).
2. Press Play. The main scene is `scenes/level.tscn`.

| Input | Action |
| --- | --- |
| WASD / arrow keys | Move |
| Mouse | Aim |
| Left click / Space | Fire |
| R | Reload |
| E | Use what you are next to (cabin door, bed, table, fireplace) |
| M | Mute or unmute the music |
| Esc / Options button | Open the volume menu (pauses the game) |
| Enter / click Play | Start from the title screen, and Play again on the end screen |

On a touch screen (iPhone) the sticks appear: the left half of the screen moves, the right half aims and fires, and
the R button reloads. They are tested with simulated touches only, not on a real iPhone yet. To see them on a Mac,
turn on `always_show` on the `Overlay` node in `ui/touch_controls.tscn`.

## Project layout

| Path | Contents |
| --- | --- |
| `scenes/level.tscn` | The playable level (main scene) |
| `scenes/test_hunter.tscn` | Older test scene for the hunter and rifle |
| `actors/` | Reusable scenes: `player`, `camera_rig`, `stag`, and the animals `fox`, `deer`, `rabbit` |
| `ui/hud.tscn` | HUD and the win and lose screens |
| `ui/title.tscn` | Title screen, shown over the level once per run |
| `ui/options.tscn` | Options menu with the Music and Effects volume sliders |
| `ui/touch_controls.tscn` | Thumb sticks and reload button for touch screens |
| `scripts/` | GDScript for the player, stag, wandering animals, camera, HUD, ammo box and campfire light |
| `assets/` | Imported models (characters, animals, nature, survival props, rocks, weapons) |
| `audio/` | Sound effects and music (generated, see `tools/gen_sounds.py` and `tools/gen_music.py`) |
| `tools/gen_sounds.py`, `tools/gen_music.py` | Synthesise the sound effects and the two music loops |
| `docs/game-design.html` | The design page |

## Status

Working: movement, mouse aiming, hitscan revolver with ammo and reload, the river and forest level, wandering foxes,
deer and rabbits, the stag with navigation, the HUD, the win and lose screens, sound effects and background music.

Not built: a mute button for touch screens, recoil. Touch controls are not yet tried on a real iPhone. See the design page for the
full list.

## Asset credits

| Used for | Source | License |
| --- | --- | --- |
| Hunter (`Adventurer`) | Quaternius, Ultimate Modular Men | CC0 |
| Stag, fox, deer | Quaternius, Ultimate Animated Animals | CC0 |
| Pines, bushes, grass, stumps, logs | Kenney, Nature Kit | CC0 |
| Campfire, barrel, box, signpost | Kenney, Survival Kit | CC0 |
| Gun, rocks, rabbit | Placeholder shapes built in the project | n/a |

The original gun, rock and rabbit models could not be redistributed, so this public copy uses simple placeholder
shapes (`actors/placeholder_gun.tscn`, `scenes/rock_placeholder.tscn`, a capsule in `actors/rabbit.tscn`). Drop in your
own models to replace them. For a new gun, see the `WEAPONS` spec in `scripts/player.gd`.

## License

The code is MIT licensed (see `LICENSE`). The third-party models keep their own CC0 licenses, listed above.
