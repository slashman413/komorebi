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

- A notification is created **ONLY when a daily run fails** — green runs send
  nothing. The notification is a **GitHub Issue** on this repo (the SMTP email
  option was deliberately not used — see §5).
- The issue contains the failure title (`⚠️ Daily tests FAILED — Run #<n>`), a
  direct link to the failed Actions run, and the **full report inlined** (with a
  `(no report available)` fallback), labeled `ci-failure` + `daily-tests`.
- It is created by `actions/github-script@v7` in the last step, gated with
  `if: failure()`, so it fires exactly once per failed run. The job's
  `permissions: issues: write` is what makes issue creation possible (the repo's
  default token is read-only).

### 5. Secrets

**The current workflow uses no secrets at all** — the GitHub Issue fallback runs
on the workflow's default token, so there is nothing to configure. The SMTP email
variant was intentionally **not** wired in (J5), but if you ever switch to email
notifications you would add these repository secrets and use an
`action-send-mail`-style step, all firing only on failure:

| Secret            | Purpose                                              |
|-------------------|------------------------------------------------------|
| `MAIL_SERVER`     | SMTP server hostname (e.g. `smtp.gmail.com`)         |
| `MAIL_PORT`       | SMTP port (e.g. `587` for STARTTLS)                  |
| `MAIL_USERNAME`   | SMTP login username                                  |
| `MAIL_PASSWORD`   | SMTP password / app password                         |
| `REPORT_TO`       | Recipient address for the failure report             |

**To change the notification recipient today (issue path):** nothing to do — the
issue lands on this repo's issue tracker. If email is enabled later, set
`REPORT_TO` to the new address in Settings → Secrets and variables → Actions.

### 6. Manual trigger

Run the tests anytime, without waiting for the schedule:

- **UI:** GitHub → **Actions** → **Daily Tests** → **Run workflow** → pick a
  branch → **Run workflow**.
- **CLI:** `gh workflow run daily-tests.yml` (optionally `--ref <branch>`).

The run executes the exact same steps (including report upload and the
failure-only issue), so it also serves as an on-demand smoke test.

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
