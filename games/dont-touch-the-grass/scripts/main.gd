# The game itself. Creates the player, the level and the systems, and connects them:
# monster catches player -> jumpscare -> back to the start of the level; player reaches the finish pad -> level completed.
#
# Start arguments (after `--`):
#   --playtest      run the automatic test and print the results (see dev/playtest.gd)
#   --shots=<dir>   save screenshots of the level into <dir>
extends Node3D

signal level_completed(number: int)

const LevelData = preload("res://scripts/level/level_data.gd")
const LevelScript = preload("res://scripts/level/level.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const PauseScript = preload("res://scripts/ui/pause_menu.gd")
const ChaseScript = preload("res://scripts/systems/chase_manager.gd")
const JumpscareScript = preload("res://scripts/systems/jumpscare.gd")
const NarratorScript = preload("res://scripts/systems/narrator.gd")
const SoundBank = preload("res://scripts/systems/sound_bank.gd")
const Materials = preload("res://scripts/materials.gd")
const PlaytestScript = preload("res://scripts/dev/playtest.gd")

const MAX_RENDER_HEIGHT := 1080.0

enum Phase { PLAYING, DYING, FINISHING }

var phase := Phase.PLAYING
var level_number := 1
var deaths := 0
var completed_levels: Array[int] = []
var started := false
var hold_level := false       # playtest: finishing does not advance
var finish_fade := 1.2
var _countdown := -1.0

var level: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var chase: Node
var jumpscare: Node
var narrator: Node
var _sting: AudioStreamPlayer
var _scratch: AudioStreamPlayer3D
var _heart: AudioStreamPlayer
var _danger := 0.0
var pause_menu: CanvasLayer
var _scratch_wait := 12.0
var _stir := 0.0
var _automated := false


func _ready() -> void:
	_bind_input()
	var args := OS.get_cmdline_user_args()
	var playtest := "--playtest" in args
	var shots_dir := ""
	for arg in args:
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	_automated = playtest or shots_dir != ""

	hud = HudScript.new()
	add_child(hud)
	pause_menu = PauseScript.new()
	add_child(pause_menu)
	narrator = NarratorScript.new()
	narrator.muted = _automated
	add_child(narrator)
	chase = ChaseScript.new()
	add_child(chase)
	jumpscare = JumpscareScript.new()
	add_child(jumpscare)
	player = PlayerScript.new()
	player.name = "Player"
	player.require_mouse_capture = not _automated
	_audio()
	chase.chase_started.connect(_on_chase_started)

	_load_level(1)
	hud.show_hint(not _automated)
	get_window().size_changed.connect(_fit_render_scale)
	_fit_render_scale()

	if _automated:
		var runner := PlaytestScript.new()
		add_child(runner)
		runner.run(self, shots_dir)


# The 3D picture is drawn at no more than MAX_RENDER_HEIGHT lines and stretched to the window.
# Without this a 4K or Retina screen draws four times the pixels of a 1080p one and the frame rate collapses.
# The level counter and other 2D parts stay sharp.
func _fit_render_scale() -> void:
	var height := float(get_window().size.y)
	get_viewport().scaling_3d_scale = clampf(MAX_RENDER_HEIGHT / maxf(height, 1.0), 0.4, 1.0)


func _input(event: InputEvent) -> void:
	if _automated:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			hud.show_hint(false)
			begin()


# The first click. The narrator opens the game once.
func begin() -> void:
	if started:
		return
	started = true
	narrator.say("intro")
	narrator.say("tutorial_move")
	narrator.say("tutorial_jump")


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or phase != Phase.PLAYING:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("stream_push"):
		_push_backward()
	elif event.is_action_pressed("stream_level_up"):
		go_to_level(level_number + 1)
	elif event.is_action_pressed("stream_level_down"):
		go_to_level(level_number - 1)
	elif event.is_action_pressed("stream_level_up5"):
		go_to_level(level_number + 5)
	elif event.is_action_pressed("stream_level_down5"):
		go_to_level(level_number - 5)
	elif event.is_action_pressed("stream_add_monster"):
		_add_monster()
	elif event.is_action_pressed("stream_reset_arm"):
		_arm_reset()
	elif event.is_action_pressed("stream_reset_now"):
		reset_run()
	elif event.is_action_pressed("stream_reset_save"):
		_save_run()


func _process(delta: float) -> void:
	if chase == null or level == null or get_tree().paused:
		return
	if _countdown >= 0.0:
		_countdown -= delta
		hud.set_countdown(_countdown)
		if _countdown <= 0.0:
			reset_run()
			return
	var want := 1.0 if chase.player_in_danger else 0.0
	_danger = move_toward(_danger, want, delta * 3.0)
	hud.set_danger(_danger)
	if _danger > 0.04:
		if not _heart.playing:
			_heart.play()
		_heart.volume_db = lerpf(-30.0, -12.0, _danger)
	elif _heart.playing:
		_heart.stop()
	# The grass shivers while monsters are hunting and settles when they give up.
	_stir = move_toward(_stir, 1.0 if chase.chase_active else 0.0, delta * 2.0)
	level.grass.set_stir(_stir)
	_scratch_wait -= delta
	if _scratch_wait <= 0.0:
		_scratch_wait = randf_range(9.0, 22.0)
		var angle := randf() * TAU
		_scratch.global_position = player.global_position + Vector3(cos(angle), 0.1, sin(angle)) * randf_range(10.0, 18.0)
		_scratch.play()


func _load_level(number: int) -> void:
	if level:
		# Out of the tree first, so its monsters stop counting at once.
		remove_child(level)
		level.queue_free()
	level_number = number
	level = LevelScript.new()
	level.name = "Level%d" % number
	add_child(level)
	level.build(LevelData.get_level(number))
	if not player.is_inside_tree():
		# The player enters the world already standing on the first platform. Entering at 0,0,0 would count as touching grass.
		player.position = level.start_position()
		add_child(player)
	level.finish.reached.connect(_on_finish_reached)
	chase.bind(player, level.hazard)
	level.spawn_enemies(player, chase)
	for enemy in level.enemies:
		enemy.caught_player.connect(_on_enemy_caught)
	hud.set_level(number, LevelData.TOTAL_LEVELS)
	if number == 10 or number == 25 or number == 50:
		narrator.say("milestone_%d" % number)
	_restart_level()


# Player back on the first platform, monsters calm and back where they started.
func _restart_level() -> void:
	chase.reset()
	for enemy in level.enemies:
		enemy.reset_to_home()
	level.finish.reset()
	player.teleport(level.start_position(), level.start_yaw())
	player.unlock()


func _on_chase_started() -> void:
	_sting.play()
	narrator.say("grass")


# A monster reached the player on the grass. Only the first report counts until the player is alive again.
func _on_enemy_caught(enemy: CharacterBody3D) -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.DYING
	deaths += 1
	for other in level.enemies:
		other.frozen = true
	await jumpscare.play(player, enemy, hud)
	_restart_level()
	# Not after every single death: the first, then two out of three, with a different line for repeat offenders.
	if deaths % 3 == 0:
		narrator.say("death_many")
	elif deaths % 3 != 1 or deaths == 1:
		narrator.say("death")
	phase = Phase.PLAYING
	hud.fade_in(0.6)


func _on_finish_reached() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.FINISHING
	if not completed_levels.has(level_number):
		completed_levels.append(level_number)
	level_completed.emit(level_number)
	print("level %d completed" % level_number)
	narrator.say("level_complete")
	player.lock()
	await hud.fade_out(finish_fade)
	if hold_level or not LevelData.has_level(level_number + 1):
		_restart_level()
	else:
		_load_level(level_number + 1)
	phase = Phase.PLAYING
	hud.fade_in(0.8)


func _audio() -> void:
	# A little room echo on everything sells the size of the hall.
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.75
	reverb.damping = 0.6
	reverb.wet = 0.22
	reverb.dry = 0.9
	AudioServer.add_bus_effect(0, reverb)

	var hum := AudioStreamPlayer.new()
	hum.stream = SoundBank.hum()
	hum.volume_db = -17.0
	add_child(hum)
	hum.play()

	_sting = AudioStreamPlayer.new()
	_sting.stream = SoundBank.sting()
	_sting.volume_db = -3.0
	add_child(_sting)

	_scratch = AudioStreamPlayer3D.new()
	_scratch.stream = SoundBank.scratch()
	_scratch.unit_size = 5.0
	_scratch.max_distance = 60.0
	_scratch.volume_db = -6.0
	_scratch.attenuation_filter_cutoff_hz = 2400.0
	add_child(_scratch)

	var music := AudioStreamPlayer.new()
	music.stream = SoundBank.music()
	music.volume_db = -24.0
	add_child(music)
	music.play()

	_heart = AudioStreamPlayer.new()
	_heart.stream = SoundBank.heartbeat()
	_heart.volume_db = -30.0
	add_child(_heart)


# Let go of the shared materials and sounds when the game closes, so Godot exits without leak warnings.
func _exit_tree() -> void:
	Materials.clear()
	SoundBank.clear()


func toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		pause_menu.close()
		if player.require_mouse_capture:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			hud.show_hint(false)
	else:
		get_tree().paused = true
		pause_menu.open(player.fov)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func go_to_level(number: int) -> void:
	var next := clampi(number, 1, LevelData.TOTAL_LEVELS)
	if next == level_number or phase != Phase.PLAYING:
		return
	_load_level(next)


func reset_run() -> void:
	_countdown = -1.0
	hud.set_countdown(-1.0)
	deaths = 0
	completed_levels.clear()
	phase = Phase.PLAYING
	_load_level(1)
	narrator.say("reset")


func _push_backward() -> void:
	var back := player.global_transform.basis.z
	back.y = 0.0
	if back.length() < 0.01:
		return
	back = back.normalized()
	player.velocity.x = back.x * 11.0
	player.velocity.z = back.z * 11.0
	player.velocity.y = 3.2


func _add_monster() -> void:
	var kind := "spider" if level_number >= 25 else "ant"
	var back := player.global_position + player.global_transform.basis.z * 4.0
	level.spawn_enemy(kind, Vector2(back.x, back.z), player, chase)
	var enemy: CharacterBody3D = level.enemies[-1]
	enemy.caught_player.connect(_on_enemy_caught)


func _arm_reset() -> void:
	if _countdown >= 0.0:
		return
	_countdown = 60.0
	hud.set_countdown(_countdown)


func _save_run() -> void:
	if _countdown < 0.0:
		return
	_countdown = -1.0
	hud.set_countdown(-1.0)
	hud.show_saved()


func _bind_input() -> void:
	_bind("stream_push", KEY_F1)
	_bind("stream_level_up", KEY_F2)
	_bind("stream_level_down", KEY_F3)
	_bind("stream_level_up5", KEY_F4)
	_bind("stream_level_down5", KEY_F5)
	_bind("stream_add_monster", KEY_F6)
	_bind("stream_reset_arm", KEY_F7)
	_bind("stream_reset_now", KEY_F8)
	_bind("stream_reset_save", KEY_F9)


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == key:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
