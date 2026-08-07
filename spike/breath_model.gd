class_name BreathModel
extends RefCounted

## Pure, side-effect-free model of the 4-7-8 breathing cycle.
##
## Everything about the breath timing lives here as static functions so it can be
## unit-tested in isolation (see tests/run_tests.gd) without a scene tree, an
## audio device, or a controller. The runtime clock (BreathClock) and every
## consumer (visual / audio / haptics / overlay) read from THIS single source of
## truth — that is the "single-clock fan-out" the spike is de-risking.

enum Phase { INHALE, HOLD, EXHALE }

const INHALE_SEC: float = 4.0
const HOLD_SEC: float = 7.0
const EXHALE_SEC: float = 8.0
const CYCLE_SEC: float = INHALE_SEC + HOLD_SEC + EXHALE_SEC ## 19.0 s per full cycle.

## Which phase a given time-within-cycle falls in. [param cycle_time] is expected
## in the range [0, CYCLE_SEC); callers should wrap with fposmod() first.
static func phase_at(cycle_time: float) -> Phase:
	var t: float = fposmod(cycle_time, CYCLE_SEC)
	if t < INHALE_SEC:
		return Phase.INHALE
	if t < INHALE_SEC + HOLD_SEC:
		return Phase.HOLD
	return Phase.EXHALE

## Normalized progress 0..1 through the CURRENT phase.
static func phase_progress(cycle_time: float) -> float:
	var t: float = fposmod(cycle_time, CYCLE_SEC)
	match phase_at(t):
		Phase.INHALE:
			return clampf(t / INHALE_SEC, 0.0, 1.0)
		Phase.HOLD:
			return clampf((t - INHALE_SEC) / HOLD_SEC, 0.0, 1.0)
		_:
			return clampf((t - INHALE_SEC - HOLD_SEC) / EXHALE_SEC, 0.0, 1.0)

## Lung-fullness amplitude 0..1. Rises on inhale, holds full, falls on exhale.
## smoothstep() gives the eased, organic feel a linear ramp cannot.
static func amplitude(cycle_time: float) -> float:
	var p: float = phase_progress(cycle_time)
	match phase_at(cycle_time):
		Phase.INHALE:
			return smoothstep(0.0, 1.0, p)
		Phase.HOLD:
			return 1.0
		_:
			return smoothstep(0.0, 1.0, 1.0 - p)

## Human-readable cue for UI / logging. Kept here so labels never drift from the enum.
static func phase_label(phase: Phase) -> String:
	match phase:
		Phase.INHALE:
			return "Inhale"
		Phase.HOLD:
			return "Hold"
		_:
			return "Exhale"
