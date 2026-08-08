# Komorebi

**A meditative game that fuses 4-7-8 guided breathing with contemplative mountain climbing.**
Breathe in for 4, hold for 7, out for 8 — the mountain answers your breath. Built for the
Steam Deck (haptic breath feedback), also Windows and Linux.

Godot **4.3+**, GDScript, statically typed throughout.

[![CI](https://github.com/slashman413/komorebi/actions/workflows/ci.yml/badge.svg)](https://github.com/slashman413/komorebi/actions/workflows/ci.yml)

> **Status:** playable vertical-slice / demo-alpha. The core breathing engine, a greybox
> climb, ecology + soundscape systems, telemetry, and store-CTA onboarding are in.
> Public store listings are the next step — see **[LAUNCH.md](LAUNCH.md)**.

---

## The core hook

A single authoritative **BreathClock** drives everything you see and feel — the orb, the
procedural audio cues, and the controller haptics — so they **cannot drift relative to each
other**. `BreathModel` holds the pure 4-7-8 timing (4 s inhale, 7 s hold, 8 s exhale = 19 s
cycle) as unit-tested static functions. Try the breathing rhythm in your browser on the
[landing page](https://slashman413.github.io/komorebi/) (no install).

## What's in the build

```
komorebi/
├── autoload/            # service layer: save (atomic, versioned), steam (stub), input, director, telemetry
├── spike/               # the Breathing Spike — single-clock breath: model, clock, visual, audio, haptics, drift overlay
├── src/
│   ├── level/           # vertical_slice: greybox climb + onboarding + wishlist/itch CTAs
│   ├── systems/         # climb, camera, ecology, soundscape, audio director
│   ├── nodes/           # climb holds
│   └── locale/          # locale table (i18n-ready)
├── tools/               # content linter + hold-graph validator
├── tests/               # dependency-free headless runner (gates CI)
├── web/                 # GitHub Pages landing page (playable JS breathing orb)
└── .github/workflows/   # ci.yml (import+parse+test+export), pages.yml, release.yml (butler → itch.io)
```

## Run it locally

Requires Godot 4.3+.

```bash
godot --path .          # runs the vertical slice
# In-app: F3 toggles the drift overlay, Esc pauses.

# Headless tests exactly as CI runs them:
godot --headless --path . --script res://tests/run_tests.gd ; echo "exit=$?"
```

A connected gamepad (or the Deck's built-in controller) enables haptics; without one the
game runs visual + audio only.

## Continuous delivery

- **`ci.yml`** — import, per-script parse gate, headless tests, then export Linux + Windows
  builds as artifacts. Runs on every push.
- **`pages.yml`** — publishes `web/` to GitHub Pages on push to the default branch.
- **`release.yml`** — on a `v*` tag, exports Linux + Windows and pushes them to itch.io via
  [butler](https://itch.io/docs/butler/). Requires a one-time `BUTLER_API_KEY` repo secret;
  skips cleanly if it is absent. See **[LAUNCH.md](LAUNCH.md)**.

## Toward revenue

The honest path for a solo Godot dev: a free "pay-what-you-want" demo on **itch.io** as the
top of a wishlist funnel to a paid **Steam** release. The remaining gates are steps only the
account owner can take (create the store pages, pay the Steam Direct fee, add the itch API
key). Everything automatable is wired; the checklist is in **[LAUNCH.md](LAUNCH.md)**, and
launch copy is in **[store/](store/)**.
