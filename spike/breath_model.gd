class_name BreathModel
extends RefCounted

enum Phase { INHALE, HOLD, EXHALE }

static var is_onboarding: bool = false

static func get_inhale_sec() -> float:
	return 3.0 if is_onboarding else 4.0

static func get_hold_sec() -> float:
	return 5.0 if is_onboarding else 7.0

static func get_exhale_sec() -> float:
	return 6.0 if is_onboarding else 8.0

static func get_cycle_sec() -> float:
	return get_inhale_sec() + get_hold_sec() + get_exhale_sec()

static func phase_at(cycle_time: float) -> Phase:
	var t: float = fposmod(cycle_time, get_cycle_sec())
	if t < get_inhale_sec():
		return Phase.INHALE
	if t < get_inhale_sec() + get_hold_sec():
		return Phase.HOLD
	return Phase.EXHALE

static func phase_progress(cycle_time: float) -> float:
	var t: float = fposmod(cycle_time, get_cycle_sec())
	match phase_at(t):
		Phase.INHALE:
			return clampf(t / get_inhale_sec(), 0.0, 1.0)
		Phase.HOLD:
			return clampf((t - get_inhale_sec()) / get_hold_sec(), 0.0, 1.0)
		_:
			return clampf((t - get_inhale_sec() - get_hold_sec()) / get_exhale_sec(), 0.0, 1.0)

static func amplitude(cycle_time: float) -> float:
	var p: float = phase_progress(cycle_time)
	match phase_at(cycle_time):
		Phase.INHALE:
			return smoothstep(0.0, 1.0, p)
		Phase.HOLD:
			return 1.0
		_:
			return smoothstep(0.0, 1.0, 1.0 - p)

static func phase_label(phase: Phase) -> String:
	match phase:
		Phase.INHALE:
			return "Inhale"
		Phase.HOLD:
			return "Hold"
		_:
			return "Exhale"
