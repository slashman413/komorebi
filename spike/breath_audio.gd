class_name BreathAudio
extends AudioStreamPlayer

## Audio cue for the fan-out. Rather than ship .wav assets in Increment 0, we
## synthesize soft sine cues procedurally at startup — zero binary assets, fully
## deterministic, and it proves audio is driven by the SAME clock as visual and
## haptics (it listens to BreathClock.phase_changed, not its own timer).
##
## Headless-safe: on a machine with no audio device Godot simply no-ops playback;
## nothing here crashes the CI parse/import gate.

@export var clock_path: NodePath
@export var enabled: bool = true

const MIX_RATE: int = 22050

var _tone_inhale: AudioStreamWAV
var _tone_hold: AudioStreamWAV
var _tone_exhale: AudioStreamWAV

@onready var _clock: BreathClock = get_node(clock_path) as BreathClock

func _ready() -> void:
	_tone_inhale = _make_tone(330.0, 0.6, true)   # rising, gentle
	_tone_hold = _make_tone(392.0, 0.18, false)   # short marker
	_tone_exhale = _make_tone(262.0, 0.8, false)  # lower, falling
	if _clock != null:
		_clock.phase_changed.connect(_on_phase_changed)
	else:
		push_error("BreathAudio: clock_path did not resolve to a BreathClock.")

func _on_phase_changed(phase: int) -> void:
	if not enabled:
		return
	match phase:
		BreathModel.Phase.INHALE:
			stream = _tone_inhale
		BreathModel.Phase.HOLD:
			stream = _tone_hold
		_:
			stream = _tone_exhale
	play()

## Build a mono 16-bit sine tone with a soft attack/decay envelope so cues never
## click. [param rising] applies a slight upward pitch glide for the inhale.
func _make_tone(freq: float, seconds: float, rising: bool) -> AudioStreamWAV:
	var count: int = int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(count)
		# Attack-decay envelope (quarter-sine in, cosine tail out).
		var env: float = sin(clamp(progress * 4.0, 0.0, 1.0) * PI * 0.5)
		env *= smoothstep(1.0, 0.6, progress)
		var f: float = freq * (1.0 + (0.12 * progress if rising else 0.0))
		var sample: float = sin(TAU * f * t) * env * 0.28
		# Little-endian 16-bit PCM (PackedByteArray has no encode_s16 in Godot 3.x).
		var sample16: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample16 & 0xFF
		data[i * 2 + 1] = (sample16 >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
