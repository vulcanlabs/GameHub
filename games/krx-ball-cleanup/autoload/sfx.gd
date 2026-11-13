extends Node
## Audio buses and the sound library.
##
## PLACEHOLDER AUDIO. No recorded sound ships with this milestone. Every sound below is synthesized from maths
## when the game starts, so the vacuum, the balls and the footsteps are not silent while the real recordings
## are sourced (Freesound needs an account to download originals; see ASSET_CREDITS.md).
##
## To replace one, save a file as res://assets/audio/<name>.ogg (or .wav, .mp3). It is picked up instead of the
## synthesized version and nothing else changes. Names: vacuum_motor, vacuum_air, ball_pop, ball_pour,
## warn_full, step_tile, room_hum, ui_click, unlock, vent_hum, plastic_creak, distant_metal, ball_bounce_far.

const RATE := 22050

## One bus per volume slider. Each feeds Master. Music and Monster carry nothing yet.
const BUSES := ["Music", "Footsteps", "Vacuum", "Balls", "Environment", "Alerts", "Monster"]
const BUS_SETTING := {
	"Master": "master", "Music": "music", "Footsteps": "footsteps", "Vacuum": "vacuum",
	"Balls": "balls", "Environment": "environment", "Alerts": "alerts", "Monster": "monster",
}
const NAMES := ["vacuum_motor", "vacuum_air", "ball_pop", "ball_pour", "warn_full", "step_tile", "room_hum", "ui_click", "unlock", "error", "vent_hum", "plastic_creak", "distant_metal", "ball_bounce_far", "water_splash"]

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	_apply_volumes()
	Settings.changed.connect(_on_setting_changed)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	# Build every sound now. Doing it on first use would stall the first vacuum press.
	for sound: String in NAMES:
		stream(sound)


func stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var found: AudioStream = null
	for extension: String in ["ogg", "wav", "mp3"]:
		var file := "res://assets/audio/%s.%s" % [sound, extension]
		if ResourceLoader.exists(file):
			found = load(file)
			break
	if found == null:
		found = call("_make_" + sound)
	_streams[sound] = found
	return found


## Plays a short sound once, with no position in the world.
func play(sound: String, bus: String, volume_db := 0.0, pitch := 1.0) -> void:
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream(sound)
	voice.bus = bus
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()


func _on_setting_changed(section: String, _key: String) -> void:
	if section == "audio":
		_apply_volumes()


func _apply_volumes() -> void:
	for bus: String in BUS_SETTING:
		var level: float = Settings.get_value("audio", BUS_SETTING[bus])
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(index, level <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))


# ---------------------------------------------------------------- synthesized placeholders

# Shop-vac body: a 60 Hz hum, a soft blade whine, and a slow pulse. Every tone is a whole number of
# cycles in one second, so the loop does not click.
func _make_vacuum_motor() -> AudioStreamWAV:
	var out := _buffer(1.0)
	var rng := _rng(1)
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var body := sin(TAU * 60.0 * t)
		body += 0.55 * sin(TAU * 120.0 * t + 0.35)
		body += 0.22 * sin(TAU * 180.0 * t + 0.8)
		body += 0.08 * sin(TAU * 240.0 * t + 1.2)
		var whine := sin(TAU * 480.0 * t + sin(TAU * 6.0 * t) * 2.2)
		var pulse := 0.78 + 0.22 * sin(TAU * 8.0 * t)
		low += ((rng.randf() - 0.5) - low) * 0.035
		var s := body * 0.4 * pulse + whine * 0.02 + low * 0.72
		out[i] = s / (1.0 + absf(s) * 0.55) * 0.7
	return _wav(_loopable(out, 0.0), true)


# Low whoosh with a slow suck, not a hiss. Tones close on a 2 second loop.
func _make_vacuum_air() -> AudioStreamWAV:
	var length := 2.0
	var fade := 0.2
	var out := _buffer(length + fade)
	var rng := _rng(2)
	var low := 0.0
	var mid := 0.0
	var high := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := (rng.randf() - 0.5) * 2.0
		low += (noise - low) * 0.03
		mid += (noise - mid) * 0.1
		high += (noise - high) * 0.22
		var suck := 0.75 + 0.25 * sin(TAU * 2.0 * t)
		var whoosh := (mid - low) * 0.95 + (high - mid) * 0.04
		var tone := sin(TAU * 140.0 * t) * 0.05 * suck
		out[i] = (whoosh * suck + tone) * 0.55
	return _wav(_loopable(out, fade), true)


# Plastic ball sucked in: a pitch drop, a short tick, and a low thock.
func _make_ball_pop() -> AudioStreamWAV:
	var out := _buffer(0.14)
	var rng := _rng(3)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var drop := 1.0 - pow(1.0 - t / 0.14, 2.4)
		phase += lerpf(720.0, 140.0, drop) / RATE
		var body := sin(TAU * phase) * exp(-t * 18.0)
		var tick := sin(TAU * 1400.0 * t) * exp(-t * 90.0)
		var thock := sin(TAU * 110.0 * t) * exp(-t * 22.0)
		var click := (rng.randf() - 0.5) * exp(-t * 280.0)
		var s := body * 0.55 + tick * 0.12 + thock * 0.62 + click * 0.35
		out[i] = s / (1.0 + absf(s) * 0.4)
	return _wav(out, false)


# Balls rattling into the pit: short pops, about 70 a second. Taps that run past the end wrap to the start.
func _make_ball_pour() -> AudioStreamWAV:
	var length := 1.2
	var out := _buffer(length)
	var rng := _rng(4)
	var tap := int(0.045 * RATE)
	for n in int(length * 70.0):
		var start := rng.randi_range(0, out.size() - 1)
		var tone := rng.randf_range(280.0, 1400.0)
		var loud := rng.randf_range(0.18, 0.55)
		var tick := rng.randf_range(1600.0, 2600.0)
		for k in tap:
			var t := float(k) / RATE
			var at := (start + k) % out.size()
			var s := sin(TAU * tone * t) * exp(-t * 42.0) * loud
			s += sin(TAU * tick * t) * exp(-t * 180.0) * loud * 0.35
			out[at] += s
	var peak := 0.001
	for sample in out:
		peak = maxf(peak, absf(sample))
	for i in out.size():
		out[i] = out[i] / peak * 0.8
	return _wav(out, true)


# Two falling beeps: the tank is full.
func _make_warn_full() -> AudioStreamWAV:
	var out := _buffer(0.5)
	for i in out.size():
		var t := float(i) / RATE
		var tone := 740.0 if t < 0.22 else 554.0
		var local := t if t < 0.22 else t - 0.26
		var gate := 0.0
		if local >= 0.0 and local < 0.18:
			gate = minf(local / 0.005, 1.0) * minf((0.18 - local) / 0.02, 1.0)
		out[i] = (sin(TAU * tone * t) + 0.33 * sin(TAU * tone * 3.0 * t)) * gate * 0.5
	return _wav(out, false)


# A shoe on ceramic tile: a dull body with a hard click on top.
func _make_step_tile() -> AudioStreamWAV:
	var out := _buffer(0.12)
	var rng := _rng(6)
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := (rng.randf() - 0.5) * 2.0
		low += (noise - low) * 0.2
		var body := sin(TAU * 170.0 * t) * exp(-t * 45.0) * 0.6
		var click := (noise - low) * exp(-t * 320.0) * 0.5
		out[i] = (body + low * exp(-t * 60.0) * 0.7 + click) * 0.7
	return _wav(out, false)


# Mains hum from the light fittings with a little air movement.
func _make_room_hum() -> AudioStreamWAV:
	var length := 2.0
	var fade := 0.15
	var out := _buffer(length + fade)
	var rng := _rng(7)
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var s := 0.22 * sin(TAU * 50.0 * t) + 0.3 * sin(TAU * 100.0 * t + 0.4) + 0.12 * sin(TAU * 150.0 * t + 1.1)
		s += 0.05 * sin(TAU * 200.0 * t)
		low += ((rng.randf() - 0.5) - low) * 0.03
		out[i] = s * 0.5 + low * 1.4
	return _wav(_loopable(out, fade), true)


func _make_ui_click() -> AudioStreamWAV:
	var out := _buffer(0.04)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = sin(TAU * 1250.0 * t) * exp(-t * 130.0) * 0.5
	return _wav(out, false)


# A short denied buzz for a locked door.
func _make_error() -> AudioStreamWAV:
	var out := _buffer(0.28)
	for i in out.size():
		var t := float(i) / RATE
		var buzz := sin(TAU * 140.0 * t) + 0.4 * sin(TAU * 93.0 * t)
		out[i] = buzz * minf(t / 0.008, 1.0) * exp(-t * 9.0) * 0.45
	return _wav(out, false)


# Four rising notes: a level opened.
func _make_unlock() -> AudioStreamWAV:
	var out := _buffer(1.1)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for n in notes.size():
		var start := int(n * 0.14 * RATE)
		for k in int(0.5 * RATE):
			if start + k >= out.size():
				break
			var t := float(k) / RATE
			var tone: float = notes[n]
			out[start + k] += (sin(TAU * tone * t) + 0.3 * sin(TAU * tone * 2.0 * t)) * minf(t / 0.004, 1.0) * exp(-t * 7.0) * 0.3
	return _wav(out, false)


# Quiet HVAC air behind the fluorescent fittings.
func _make_vent_hum() -> AudioStreamWAV:
	var length := 2.4
	var fade := 0.2
	var out := _buffer(length + fade)
	var rng := _rng(11)
	var low := 0.0
	var mid := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := (rng.randf() - 0.5) * 2.0
		low += (noise - low) * 0.02
		mid += (noise - mid) * 0.07
		var tone := 0.08 * sin(TAU * 48.0 * t) + 0.05 * sin(TAU * 96.0 * t + 0.6)
		out[i] = (low * 1.1 + (mid - low) * 0.35 + tone) * 0.42
	return _wav(_loopable(out, fade), true)


# A short plastic playground creak.
func _make_plastic_creak() -> AudioStreamWAV:
	var out := _buffer(0.55)
	var rng := _rng(12)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += lerpf(220.0, 140.0, t / 0.55) / RATE
		var body := sin(TAU * phase) * exp(-t * 4.2)
		var grain := (rng.randf() - 0.5) * exp(-t * 8.0)
		out[i] = (body * 0.55 + grain * 0.18) * minf(t / 0.02, 1.0)
	return _wav(out, false)


# Far-off duct or pole knock.
func _make_distant_metal() -> AudioStreamWAV:
	var out := _buffer(0.7)
	var rng := _rng(13)
	for i in out.size():
		var t := float(i) / RATE
		var clang := sin(TAU * 190.0 * t) * exp(-t * 6.5)
		clang += 0.35 * sin(TAU * 310.0 * t) * exp(-t * 9.0)
		var air := (rng.randf() - 0.5) * exp(-t * 12.0) * 0.2
		out[i] = (clang + air) * 0.4
	return _wav(out, false)


# One distant ball hitting a hard floor.
func _make_ball_bounce_far() -> AudioStreamWAV:
	var out := _buffer(0.22)
	var rng := _rng(14)
	for i in out.size():
		var t := float(i) / RATE
		var body := sin(TAU * 420.0 * t) * exp(-t * 22.0)
		var tick := sin(TAU * 1600.0 * t) * exp(-t * 70.0)
		var noise := (rng.randf() - 0.5) * exp(-t * 90.0)
		out[i] = (body * 0.5 + tick * 0.18 + noise * 0.12) * 0.35
	return _wav(out, false)


func _make_water_splash() -> AudioStreamWAV:
	var out := _buffer(0.45)
	var rng := _rng(21)
	var low := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var noise := (rng.randf() - 0.5) * 2.0
		low += (noise - low) * 0.18
		var body := sin(TAU * 90.0 * t) * exp(-t * 8.0)
		out[i] = (body * 0.45 + low * exp(-t * 6.0)) * 0.7
	return _wav(out, false)


func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# Folds the extra `fade` seconds at the end back over the start, so noise loops without a seam.
func _loopable(samples: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var overlap := int(fade * RATE)
	if overlap == 0:
		return samples
	var length := samples.size() - overlap
	for i in overlap:
		var mix := float(i) / overlap
		samples[i] = samples[i] * mix + samples[length + i] * (1.0 - mix)
	samples.resize(length)
	return samples


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
