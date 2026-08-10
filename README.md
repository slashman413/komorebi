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

---

## CI / Daily Tests (`.github/workflows/daily-tests.yml`)

A scheduled daily run of the full test suite, with a downloadable report and a
failure-only notification. It runs in the `barichello/godot-ci:3.5` container on
`ubuntu-latest` (env `GODOT_VERSION: "3.5.2"`).

### 1. Schedule

The workflow triggers on a cron schedule **plus** a manual `workflow_dispatch` trigger:

```yaml
on:
  schedule:
    - cron: "0 2 * * *"   # every day at 02:00 UTC
  workflow_dispatch:
```

- **Cron `0 2 * * *`** = minute 0, hour 2, every day of month, every month, every
  day of week → **daily at 02:00 UTC**.
- **Taiwan time (UTC+8, no DST): 10:00 AM (10:00) every day.**
- **To change the schedule:** edit the `cron:` line in `.github/workflows/daily-tests.yml`
  and commit/push. Note that GitHub only runs `schedule` triggers on the **default
  branch** — a cron edit on a feature branch won't fire until it lands on default.

### 2. What it tests

Five things, in order (setup steps `actions/checkout@v4` and "Provision export
templates" precede them):

1. **Import + parse gate** — `godot --headless --path . --import` (output teed to
   `import.log`), then a log-scan backstop that greps for
   `SCRIPT ERROR|Parse Error|Failed to load script` and fails the job if found.
2. **Headless tests** — `godot --headless --path . --script res://tests/run_tests.gd`
   (teed to `test_results.log`); the exit code gates the job.
3. **HoldGraph Validator** — `res://tools/validate_hold_graph.gd` (teed to
   `holdgraph_results.log`); the exit code gates the job.
4. **Content Linter** — `res://tools/content_linter.gd` (teed to `linter_results.log`);
   the exit code gates the job.
5. **Container** — `barichello/godot-ci:3.5` (Ubuntu-based, Godot 3.5.2 binaries
   preinstalled), the same image family used by the regular CI workflow.

Every gated step runs with `set -o pipefail`, so a failing command is never masked
by `tee`.

### 3. Test report

Every run — **success or failure** — generates and uploads a report:

- **Where:** GitHub Actions → the daily run → **Artifacts** →
  `daily-test-report-<run-id>` (download `report.md`). The upload step runs
  `if: always()`, so the report exists even when the run fails.
- **Contents:** run ID, date (UTC), overall job status, then four labeled sections
  — Import + Parse Gate, Headless Tests, HoldGraph Validator, Content Linter —
  each carrying the tail of that suite's log in a code block (with a
  `(no ... log)` fallback if a step never produced one).
- **Retention:** 30 days (`retention-days: 30`), then GitHub auto-deletes it.

### 4. Failure notification

- GitHub **emails the repository owner automatically** whenever a workflow run
  fails — no custom code, no secrets, nothing to configure in this repo.
- Notification scope is controlled in GitHub, not in the workflow: **Settings →
  Notifications → Actions** (per-repo) or the global notification preferences.
  "Send notifications for failed workflows" is on by default; enable "Send
  notifications for successful workflows" if you also want green-run emails.
- A failed daily run therefore produces: the built-in failure email **plus** the
  retained report artifact (see §3) — the report is always downloadable from the
  run's Artifacts tab even when the run failed.

### 5. Secrets

**The workflow uses no secrets at all** — failure notification rides on GitHub's
built-in Actions email, and the test gate itself needs no credentials. There is
nothing to configure under Settings → Secrets and variables → Actions. (An earlier
revision created a GitHub issue on failure via `actions/github-script@v7` with
`permissions: issues: write`; that step and the extra permission were removed
because they are redundant with GitHub's built-in notification.)

### 6. Manual trigger

Run the tests anytime, without waiting for the schedule:

- **UI:** GitHub → **Actions** → **Daily Tests** → **Run workflow** → pick a
  branch → **Run workflow**.
- **CLI:** `gh workflow run daily-tests.yml` (optionally `--ref <branch>`).

The run executes the exact same steps (including report upload), so it also
serves as an on-demand smoke test — useful to verify a fix before the next
scheduled run.

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
