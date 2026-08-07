# Project Komorebi — Increment 0

**Skeleton + Breathing Spike.** Goal: de-risk haptic / audio / visual sync of
4-7-8 breathing on the Steam Deck at 60 FPS.

Godot **4.3+**, GDScript, statically typed throughout.

---

## What's here

```
komorebi/
├── project.godot                 # 4.3 project; autoloads registered; Deck res (1280x800), GL Compatibility
├── export_presets.cfg            # Linux + Windows Desktop presets (x86_64)
├── icon.svg
├── autoload/                     # Autoload skeletons (service layer)
│   ├── save_service.gd           #   atomic write + schema_version:1 + migration hook
│   ├── steam_service.gd          #   stub (no GodotSteam dependency yet — keeps headless import green)
│   ├── input_router.gd           #   central input intents; tracks kbd vs. gamepad
│   └── game_director.gd          #   coarse state machine + service wiring; loads save on boot
├── spike/                        # The Breathing Spike
│   ├── breath_model.gd           #   PURE 4-7-8 math (unit-tested in isolation)
│   ├── breath_clock.gd           #   THE single clock — one tick, everything fans out from it
│   ├── breath_visual.gd          #   visual breath curve (expanding/contracting orb)
│   ├── breath_audio.gd           #   procedural sine cues (no binary assets), driven by the clock
│   ├── haptic_probe.gd           #   capability-probed rumble; degrades to silence if no pad
│   ├── drift_overlay.gd          #   live FPS + frame-clock-vs-wall-clock drift readout (F3)
│   └── breathing_spike.tscn      #   composition scene (main scene)
├── tests/
│   ├── run_tests.gd              #   dependency-free headless runner; exits 0/1 for CI
│   └── fixtures/save_v1.json     #   one committed v1 save fixture
└── .github/workflows/ci.yml      # import + parse gate + tests, then export Win+Linux + upload
```

## The single-clock design (why this de-risks sync)

Everything visible or felt reads from **one** source of truth:

- `BreathClock` accumulates frame `delta` into an authoritative `elapsed` time and
  emits exactly two signals — `breath_tick` (every frame, continuous values) and
  `phase_changed` (only on INHALE→HOLD→EXHALE transitions).
- `BreathVisual` (per-frame), `BreathAudio` and `HapticProbe` (event-driven), and
  `DriftOverlay` all **subscribe** to that clock. None of them runs its own timer.

Because there is only one timer, haptics/audio/visual **cannot drift relative to
each other**. The remaining risk — the frame clock diverging from real time under
load on the Deck — is exactly what `DriftOverlay` measures: `elapsed` (delta-summed)
vs. `real_seconds` (`Time.get_ticks_usec`), reported live in ms with a running peak.

`BreathModel` holds the 4-7-8 timing (4 s inhale, 7 s hold, 8 s exhale = 19 s cycle)
as pure static functions, so the curve is unit-tested with no scene tree.

## Run it locally

Requires Godot 4.3+.

```bash
# From the komorebi/ directory:
godot --path .                       # runs the main scene (the spike)
# In-app: F3 toggles the drift overlay, Esc pauses.

# Run the headless tests exactly as CI does:
godot --headless --path . --script res://tests/run_tests.gd ; echo "exit=$?"
```

A connected gamepad (or the Deck's built-in controller) enables haptics; without
one the spike runs visual + audio only and the overlay shows `haptics: unavailable`.

## CI (`.github/workflows/ci.yml`)

Runs in the `barichello/godot-ci:4.3` container:

1. **import-and-test** — `--import`, then a per-script `--check-only` parse gate,
   a log-scan backstop, then the headless test runner (its exit code gates the job).
2. **export** — matrix (Linux `komorebi.x86_64`, Windows `komorebi.exe`), uploads
   each build as an artifact (`komorebi-linux`, `komorebi-windows`).

---

## ⚠️ Push + first-run status (read this)

This increment was authored on a host with **no Godot binary and no target
repository / push credentials**, so two things in the task's "Output" line could
**not** be executed or verified from here and are left as the human/CI step:

- **Code push** — there is no repo to push to yet. See "How to ship" below.
- **A *proven* green pipeline** — CI is authored to pass, but has not been run,
  because that requires the push above. First run is the source of truth.

Everything that does not require a repo or a Godot binary is complete and
self-consistent: locally-verifiable JSON/YAML is valid, the code is written to the
project's typing/signal conventions, and the tests assert the SaveService and
BreathModel invariants the task calls for.

### How to ship (≈2 minutes)

```bash
cd komorebi
git init -b main
git add .
git commit -m "Komorebi Increment 0: skeleton + breathing spike"
gh repo create <owner>/komorebi --private --source=. --push   # or add a remote + push
# Open the Actions tab and confirm the CI run goes green.
```

### One thing to sanity-check on first CI run

`export_presets.cfg` is normally serialized by the Godot editor. The committed
presets are hand-written and correct for the common case, but preset options can
be version-sensitive. If the **export** job fails to find/serialize a preset,
open the project once in the editor (`Project → Export`), confirm the **Linux**
and **Windows Desktop** presets exist, save, and commit the regenerated file. The
**import-and-test** gate does not depend on presets and should pass regardless.
