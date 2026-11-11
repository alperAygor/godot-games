# Cargo native-joint quick comparison

Decision: **keep the production runtime `top_level` explicit spring**. Keep this
opt-in fixture and this measured report as reproducible negative comparison evidence;
neither trial script is referenced by `Proto.tscn` or the normal startup scene.
This was a bounded quick trial, not proof that every native-joint configuration fails.

## Execution

Godot 4.7.2.stable.official.ed1daf0bf; protected stage file was already `full`.

```sh
godot --headless --path . -s res://tools/experiments/cargo_joint_comparison.gd
godot --headless --path . -s res://tools/game_probe.gd
```

The wrapper inherits the actual protected `tools/game_probe.gd`, overrides only
`_step_load()`, instantiates the unchanged `Proto.tscn`, removes the cargo script
before tree entry, installs the trial body, and calls inherited `_go(Phase.READY)`.
All measurement phases, thresholds, deadline, input commands and ramp teleport
remain inherited and unchanged. The wrapper respects the protected stage choice.

The native trial remains a dynamic `RigidBody3D`, preserves its authored mount as
`top_level`, and creates a `Generic6DOFJoint3D` attached to the robot. Linear axes
and yaw are locked; pitch/roll have native angular springs and limits. Joint pivot
is the basket collision box's lower face, giving acceleration a real moment arm.
Mass/spring/damping/limits use existing GameData balance values (4.5 kg, 24, 5,
28 degrees). These spring coefficients have different physical units/semantics
from the production inertia-normalized explicit spring, so this is a direct quick
configuration test, not a fully optimized native-joint tuning comparison.

## Actual protected probe measurements

| Measurement | Current explicit spring | Native 6DOF trial |
|---|---:|---:|
| Rest speed (m/s) | 0.000 | 0.000 |
| Rest robot height (m) | 0.514 | 0.509 |
| Rest cargo sway (degrees) | 0.00 | 28.00 |
| Acceleration peak speed (m/s) | 7.87 | 7.84 |
| Acceleration peak sway (degrees) | 16.50 | 33.19 |
| Brake final speed (m/s) | 0.000 | 0.000 |
| Sway after braking, 240 frames (degrees) | 0.00 | 28.00 |
| Combined acceleration/braking peak sway (degrees) | 20.95 | 35.05 |
| Turn yaw change (degrees) | 54.2 | 54.4 |
| Ramp longest airborne run (frames) | 39 | 0 |
| Landed after airborne | true | false |
| Probe result / process exit | PASS / 0, frame 1151 | FAIL / 1, four failures |

Native failures reported by the probe: rest sway, post-brake damping, no ramp
airtime, and detached cargo. Temporary output logs were read and then removed. The probe's attachment
flag only says the trial violated distance/angle bounds at least once; it does
not prove the solver joint resource broke. Ramp teleport handling resets the
body pose once after a large robot move; teleport/constraint interaction remains
a trial limitation. Native sway sitting at the angular stop is an observed
symptom, not an established backend/API defect.

## Validation and limitations

- Actual protected baseline probe passed; actual inherited protected trial failed.
- Native setter names/constants were checked using studio-kit `fetch_docs.sh`
  and the generated `Generic6DOFJoint3D.xml`, not guessed.
- An initial invalid setup run was cancelled after adding a joint during parent
  `_ready()` caused a busy-parent error. Deferred joint creation fixed setup;
  the table/log uses the subsequent complete run only.
- Log output paths were initially tried as `/dev/null` and `res://...`, which
  caused logger setup warnings on this platform. Use an absolute writable
  `--log-file` path when reproducing; the logger issue did not alter probe phases.
- Trial signals are an API compatibility surface. Impact emission is deliberately
  uninstrumented (not part of this sway comparison); slosh measures native angular
  acceleration. This fixture must not replace the selected cargo code.
- No protected files, production cargo/robot scripts, balance, diagnostics, or
  production scene were edited by this comparison task. No commits were made.
- No broad tuning loop or separate core unit test: the isolated alternative is
  exercised by the real protected acceptance probe, and is intentionally rejected.
