# PLACEHOLDER AUDIO. Every sound here is synthesized from maths at startup because the project has no audio files.
# They are stand-ins so the game is not silent. Replace each function body with `load("res://audio/...")`
# once real recordings exist; nothing else in the game needs to change.
extends RefCounted

const RATE := 22050

static var _cache: Dictionary = {}


static func clear() -> void:
	_cache.clear()


# Fluorescent tube hum. Loops seamlessly.
static func hum() -> AudioStreamWAV:
	if _cache.has("hum"):
		return _cache["hum"]
	var length := 3.0
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in out.size():
		var t := float(i) / RATE
		var wobble := 0.85 + 0.15 * sin(TAU * t * 2.0 / length)
		var s := 0.30 * sin(TAU * 120.0 * t) + 0.16 * sin(TAU * 240.0 * t + 0.4)
		s += 0.09 * sin(TAU * 360.0 * t + 1.1) + 0.05 * sin(TAU * 480.0 * t) + 0.12 * sin(TAU * 60.0 * t)
		s += (rng.randf() - 0.5) * 0.02
		out[i] = s * wobble * 0.6
	_cache["hum"] = _wav(out, true)
	return _cache["hum"]


# Something dragging claws over a hard surface, far away.
static func scratch() -> AudioStreamWAV:
	if _cache.has("scratch"):
		return _cache["scratch"]
	var length := 2.0
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var strokes := [[0.05, 0.24], [0.42, 0.18], [0.70, 0.30], [1.15, 0.16], [1.40, 0.34]]
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var env := 0.0
		for stroke in strokes:
			var u: float = (t - stroke[0]) / stroke[1]
			if u > 0.0 and u < 1.0:
				env = sqrt(sin(PI * u))
		var raw := (rng.randf() - 0.5) * 2.0
		low += (raw - low) * 0.18
		var grit := 0.5 + 0.5 * signf(sin(TAU * 74.0 * t))
		out[i] = (raw - low) * env * grit * 0.5
	_cache["scratch"] = _wav(out, false)
	return _cache["scratch"]


# Low dissonant hit. Plays when a chase starts.
static func sting() -> AudioStreamWAV:
	if _cache.has("sting"):
		return _cache["sting"]
	var length := 2.2
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(t / 0.02, 1.0) * exp(-t * 1.6)
		var s := sin(TAU * 49.0 * t) + sin(TAU * 52.0 * t) + 0.6 * sin(TAU * 73.4 * t) + 0.35 * sin(TAU * 147.0 * t)
		s += (rng.randf() - 0.5) * exp(-t * 18.0) * 1.2
		out[i] = tanh(s * env * 0.9) * 0.8
	_cache["sting"] = _wav(out, false)
	return _cache["sting"]


# Dry clicking of insect legs and jaws. Loops; the enemy changes pitch and volume with its speed.
static func chitter() -> AudioStreamWAV:
	if _cache.has("chitter"):
		return _cache["chitter"]
	var length := 1.0
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var click_at := 0.0
	while click_at < length - 0.02:
		var start := int(click_at * RATE)
		var tone := rng.randf_range(1800.0, 3200.0)
		var loud := rng.randf_range(0.35, 0.9)
		for k in int(0.008 * RATE):
			var t := float(k) / RATE
			var s := sin(TAU * tone * t) * 0.6 + (rng.randf() - 0.5) * 0.8
			out[start + k] += s * exp(-t * 520.0) * loud
		click_at += rng.randf_range(0.018, 0.06)
	_cache["chitter"] = _wav(out, true)
	return _cache["chitter"]


# Jumpscare: a body thump under a tearing shriek.
static func screech() -> AudioStreamWAV:
	if _cache.has("screech"):
		return _cache["screech"]
	var length := 1.6
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var freq := lerpf(1400.0, 520.0, t / length) + 90.0 * sin(TAU * 35.0 * t)
		phase += freq / RATE
		var saw := 2.0 * fposmod(phase, 1.0) - 1.0
		var ring := saw * sin(TAU * 187.0 * t)
		var hiss := (rng.randf() - 0.5) * 2.0
		var env := minf(t / 0.01, 1.0) * (1.0 - smoothstep(1.15, length, t))
		var thump := sin(TAU * 45.0 * t) * exp(-t * 7.0)
		out[i] = tanh((saw * 0.5 + ring * 0.6 + hiss * 0.35) * 2.2) * env * 0.75 + thump * 0.85
	_cache["screech"] = _wav(out, false)
	return _cache["screech"]


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
