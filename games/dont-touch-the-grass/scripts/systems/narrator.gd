# The narrator. The game calls say("death") and this picks a line, makes sure only one line plays at a time,
# and leaves a pause before the next.
#
# How a line is voiced, first match wins:
#   1. "recording"  a file res://audio/narrator/<line id>.ogg / .wav / .mp3 exists: play it.
#   2. "tts"        no file: the computer's own text-to-speech reads the line, pitched down.
#                   This is a STAND-IN voice, not the final robotic narrator.
#   3. "missing"    no file and no text-to-speech on this machine: silence, and a warning in the output.
extends Node

signal line_started(event: String, line_id: String, backend: String)
signal line_finished(line_id: String)

const Lines = preload("res://scripts/systems/narrator_lines.gd")

const VOICE_DIR := "res://audio/narrator/"
const PAUSE_BETWEEN_LINES := 1.2
const PREFERRED_VOICES := ["Zarvox", "Fred", "Ralph", "David", "Mark", "George"]

var muted := false             # playtest: run all the rules, make no sound
var speaking := false
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _clock := 0.0
var _pause := 0.0
var _timeout := 0.0
var _last_said := {}           # event -> time it was last spoken
var _last_line := {}           # event -> id of the line used last time
var _player: AudioStreamPlayer
var _tts_voice := ""
var _utterance := 0
var _warned := {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.finished.connect(_finish)
	add_child(_player)
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		_tts_voice = _pick_voice()
		if _tts_voice != "":
			DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_done)
			DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_tts_done)


# Ask for a comment on something that happened. Returns true if a line will be spoken.
func say(event: String) -> bool:
	if not Lines.EVENTS.has(event):
		push_warning("Narrator: no lines for event '%s'" % event)
		return false
	var cfg: Dictionary = Lines.EVENTS[event]
	var cooldown: float = cfg["cooldown"]
	if _last_said.has(event) and _clock - float(_last_said[event]) < cooldown:
		return false
	var entry := {"event": event, "priority": int(cfg["priority"]), "line": _pick_line(event, cfg["lines"])}
	var busy := speaking or not _queue.is_empty()
	if busy:
		var active: int = _current.get("priority", 0) if speaking else int(_queue[0]["priority"])
		if entry["priority"] > active:
			stop()
		elif not cfg["queue"]:
			return false
	_last_said[event] = _clock
	_queue.append(entry)
	return true


# Cut off the current line and drop everything waiting.
func stop() -> void:
	_queue.clear()
	_pause = 0.0
	if not speaking:
		return
	speaking = false
	_player.stop()
	if _current.get("backend", "") == "tts":
		DisplayServer.tts_stop()
	_current = {}


func _process(delta: float) -> void:
	_clock += delta
	if speaking:
		# Safety net for backends that never report the end of a line.
		if _timeout > 0.0:
			_timeout -= delta
			if _timeout <= 0.0:
				_finish()
		return
	if _pause > 0.0:
		_pause -= delta
		return
	if not _queue.is_empty():
		_start(_queue.pop_front())


func _start(entry: Dictionary) -> void:
	var line: Dictionary = entry["line"]
	var id: String = line["id"]
	var text: String = line["text"]
	var backend := "missing"
	_timeout = 0.3
	if muted:
		backend = "muted"
	else:
		var recording := _recording(id)
		if recording != null:
			backend = "recording"
			_timeout = 0.0
			_player.stream = recording
			_player.play()
		elif _tts_voice != "":
			backend = "tts"
			_utterance += 1
			_timeout = text.length() * 0.11 + 3.0
			DisplayServer.tts_speak(text, _tts_voice, 80, 0.6, 0.9, _utterance, true)
		elif not _warned.has(id):
			_warned[id] = true
			push_warning("Narrator: no recording and no text-to-speech for '%s' (%s%s.ogg)" % [id, VOICE_DIR, id])
	speaking = true
	_current = {"id": id, "priority": entry["priority"], "backend": backend}
	line_started.emit(entry["event"], id, backend)


func _finish() -> void:
	if not speaking:
		return
	speaking = false
	_timeout = 0.0
	_pause = PAUSE_BETWEEN_LINES
	var id: String = _current.get("id", "")
	_current = {}
	line_finished.emit(id)


func _on_tts_done(utterance: int) -> void:
	if utterance == _utterance and _current.get("backend", "") == "tts":
		_finish()


# A different line from last time whenever the event has more than one.
func _pick_line(event: String, lines: Array) -> Dictionary:
	var choices := lines.filter(func(line: Dictionary) -> bool: return lines.size() == 1 or line["id"] != _last_line.get(event, ""))
	var line: Dictionary = choices.pick_random()
	_last_line[event] = line["id"]
	return line


func _recording(id: String) -> AudioStream:
	for extension: String in ["ogg", "wav", "mp3"]:
		var path := "%s%s.%s" % [VOICE_DIR, id, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null


# The flattest, most machine-like English voice this computer has. "" when it has none.
func _pick_voice() -> String:
	var english: Array[Dictionary] = []
	for voice: Dictionary in DisplayServer.tts_get_voices():
		var language: String = voice.get("language", "")
		if language.begins_with("en"):
			english.append(voice)
	for wanted: String in PREFERRED_VOICES:
		for voice in english:
			var voice_name: String = voice.get("name", "")
			if voice_name.contains(wanted):
				return voice["id"]
	return "" if english.is_empty() else english[0]["id"]
