# Cable Knot: Current Master

A high-voltage untangling puzzle with a calm, ASMR atmosphere. Untangle colored cables, thread
them past each other without shorting, and snap every plug into its matching socket.

- **Engine:** Godot 4.7.2 (GDScript, no C#)
- **Platform:** Android, portrait 1080×1920, `gl_compatibility` renderer
- **Target:** 60 FPS desktop / ≥30 FPS low-end mobile, one-hand play, 12 levels (45–105 s)
- **Languages:** English + Turkish (in-game switch, persisted)
- **Store title:** Cable Knot: Current Master · TR: Kablo Düğümü: Akım Ustası

## How to play

1. **Study the tangle** — the main panel on top feeds colored cables; the socket strip sits below.
2. **Drag a plug** — touch a plug head and move it; the cable lifts and follows with soft rope physics.
3. **Break contact** — when two cables of *different* colors touch, sparks fly and the overload bar
   starts filling. Break the contact to let it drain. At 100% the fuse blows and the level fails.
4. **Snap it** — drop a plug on the socket of the same color for a satisfying "clack".
   A wrong-color socket arcs, adds load, and bounces the plug back.
5. **Balance the circuit** — when every plug is seated the level is complete.

Same-color contact is safe. Cables have a fixed length — you cannot pull a plug past its reach.

### Controls
- **Touch & drag:** move the plug (mouse emulated as touch on desktop).
- **Esc / Android back:** back (pause in game, quit in menu).
- HUD: pause, Golden Cutter, Insulation Spray.

## Progression & mechanics

| Levels | New element |
|---|---|
| 1–4 | Basics: 3→4 cables, gentle tutorial hints |
| 5+ | **Sway** — live, swaying bare wires you must not touch |
| 7+ | **Locked sockets** — hold the plug on the socket for 0.6 s to open the cover |
| 9+ | **Blackout** — panel lights slowly fade and return (visual challenge) |
| 10+ | **Fast overload** — the load bar fills 1.5× faster |
| 12 | Seven cables, all modifiers, tightest par time |

Stars: clean run within par = 3 · ≤2 short circuits and 1.6× par = 2 · completed = 1.

## Rewarded ad hooks

| Placement | Trigger | Reward |
|---|---|---|
| `FUSE_RESCUE` | Fuse blows | Resets load + 15 s insulation shield, continue the level |
| `GOLDEN_CUTTER` | In-level button (1/level) | Auto-connects the most tangled plug with a golden arc |
| `INSULATION_SPRAY` | In-level button (1/level) | 10 s shield: contact no longer fills the overload bar |

Development uses `MockAdsProvider` (1.2 s simulation, 8% no-fill). To ship a real SDK, implement
`scripts/services/ads_provider.gd`; no game code changes. Limits live in `data/ads.json`.

## ASMR design direction (v0.2)

- Warm-dark workshop ambience, low contrast, soft bloom, dust motes, breathing panel lights.
- Animated background in the menu and behind the game panel: slowly rotating fan, swinging pendant
  lamp, conveyor with spools, drifting steam.
- Soft audio: muffled sparks, wooden clacks, fabric cable slide, warm chimes, seamless ambient
  hum/pad loops. **Most important:** the game should feel relaxing, not panicky.
- Gentle easing on every interaction; no harsh white/red flashes.

## Localization

All user-facing text goes through `Loc` (`scripts/autoload/Loc.gd`) with tables in
`data/i18n/en.json` and `data/i18n/tr.json` (key parity enforced by tests). Language is
auto-detected from the OS on first run, switchable from the menu, persisted in
`user://settings.cfg`.

## Screenshots

Final v0.2 shots live in [docs/screenshots/](docs/screenshots/) — a 12-frame contact sheet:
[docs/screenshots/sheet.png](docs/screenshots/sheet.png) (menu EN/TR, level select, sway/locked/
blackout/L12 gameplay, short circuit, shield, fail, win celebration, result).

## Run

```bash
cd godot-games/KabloDugumu
godot --path .                     # run the game (editor: godot --path . -e)
bash tools/verify.sh               # import + boot smoke + unit tests + game probe
python3 tools/build_theme.py --check
godot --path . -s res://tools/perf_probe.gd        # frame-time report (windowed)
godot --path . -s res://tools/flow_shot.gd -- --out-dir=/tmp/kablo_shots
```

Verification scans the output for `SCRIPT ERROR|Parse Error` because Godot can exit 0 on script
errors. Red means not done.

## Project layout

```
scenes/            Boot, Menu, LevelSelect, Game, Result, HUD, AmbientBackdrop
scripts/autoload/  GameManager, AudioService, AdManager, GameData, Loc
scripts/core/      pure logic: level generation, overload, snap rules, scoring, profile, geometry (tested)
scripts/gameplay/  3D world: board, rope physics, plugs/sockets, contact, sparks, camera, backdrop
scripts/ui/        HUD and screens (presentation only)
scripts/services/  AdsProvider boundary (SDK isolated here)
data/              JSON tuning: levels, balance, ads, theme, sounds, sfx recipes, i18n
tests/             tests/unit/test_*.gd — auto-discovered, headless
tools/             verify.sh, build_theme.py, make_sfx.py, perf_probe.gd, flow_shot.gd
```

Docs: [ROADMAP.md](ROADMAP.md) (v0.2 plan), [PROJECT_SPEC.md](PROJECT_SPEC.md) (design),
[ARCHITECTURE.md](ARCHITECTURE.md) (contracts), [CLAUDE.md](CLAUDE.md) (code rules),
[TASKS.md](TASKS.md), [CHANGELOG.md](CHANGELOG.md).

## Audio generation

```bash
python3 tools/make_sfx.py                     # generate missing sounds (deterministic synth fallback)
ELEVENLABS_API_KEY=... python3 tools/make_sfx.py --force   # ElevenLabs sound generation
```

The ElevenLabs key never enters the repo; without a key the same names are produced by a
deterministic synthesizer, so the game is always voiced.

## Licenses

- Fonts: Manrope (OFL) — `assets/fonts/OFL_Manrope.txt`; Baloo 2 (OFL) — `assets/fonts/OFL_Baloo2.txt`
- Icons: Lucide (ISC) — `assets/icons/LICENSE_lucide.txt`
- 3D assets are procedural primitives; no external models.
- Audio: ElevenLabs when a key is provided, otherwise deterministic synthesis.