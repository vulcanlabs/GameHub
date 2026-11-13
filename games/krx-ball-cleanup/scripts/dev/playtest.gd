extends Node
## Developer tool, not part of the game. Plays Level 1 by itself and reports what works.
##
##   Godot --headless --fixed-fps 60 --path games/krx-ball-cleanup -- --playtest
##
## It presses the real input actions (move_forward, vacuum, unload, ...), so it tests the same code a person
## drives. One PASS or FAIL line per check, then `playtest ok` or `playtest fail`. It uses its own settings
## file (user://settings_dev.cfg) and never touches the player's.
##
##   Godot --path games/krx-ball-cleanup --windowed --resolution 1920x1080 -- --shots=/some/folder
##
## saves screenshots and measures frame time instead. That needs a real window, so no --headless.
## The numbers it prints are only true for the machine that ran it.

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "vacuum", "unload"]
const START_BALLS := 234000

var game: Node3D
var player: Player
var balls: BallManager
var pit: CollectionPit
var hud: Hud
var menu: PauseMenu
var level: Level1Hub
var _failed := 0
var _extra := 0                 # balls this test conjured into the vacuum to reach the full state quickly
var _start_layout := 0
var _filled_signals := 0


func run(p_game: Node3D, shots_dir: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = p_game
	player = game.player
	balls = game.balls
	level = game.level
	pit = level.pit
	hud = game.hud
	menu = game.pause_menu
	player.require_mouse_capture = false
	GameState.vacuum_filled.connect(func() -> void: _filled_signals += 1)
	if shots_dir != "":
		await _shots(shots_dir)
		get_tree().quit()
		return
	await _frames(5)
	await _test_start()
	await _test_movement()
	await _test_collisions()
	await _test_vacuum()
	await _test_capacity()
	await _test_unload()
	await _test_settings()
	await _test_pause()
	await _test_unlock_and_restart()
	_report_costs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	print("playtest ok" if _failed == 0 else "playtest fail (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


# ---------------------------------------------------------------- tests

func _test_start() -> void:
	_start_layout = balls.layout_hash()
	_check("1", "Level 1 holds exactly 4,000 balls", balls.count() == 4000 and GameState.remaining[0] == 4000,
		"%d in the registry, %d drawn (top %d layers of each column)" % [balls.count(), balls.drawn_count(), BallManager.SHELL])
	_check("2", "the run holds exactly 234,000 balls", GameState.total_remaining() == START_BALLS and GameState.balls_in_run() == START_BALLS,
		"levels: %s" % str(Array(GameState.remaining)))
	var problem := balls.validate()
	_check("3", "ball registry is consistent, nothing on blocked floor", problem == "", problem)
	_check("4", "piles rest at a stable slope", balls.steepest_step() < BallManager.SLOPE and not balls.settling(),
		"steepest step between neighbours: %d ball(s)" % balls.steepest_step())

	var outside := 0
	var tallest := 0
	for c in balls.columns * balls.rows:
		var h := balls.column_height(c)
		if h == 0:
			continue
		tallest = maxi(tallest, h)
		var at := balls.ball_position(c % balls.columns, c / balls.columns, h - 1)
		var in_hall: bool = absf(at.x) < level.WIDTH * 0.5 - 0.06 and absf(at.z) < level.DEPTH * 0.5 - 0.06
		var in_pit := false
		for hole in level.PITS:
			if hole.grow(CollectionPit.KERB_WIDTH + 0.06).has_point(Vector2(at.x, at.z)):
				in_pit = true
				break
		if not in_hall or in_pit:
			outside += 1
	_check("5", "every ball is inside the hall and off the pit", outside == 0,
		"%d outside, tallest pile %.2f m" % [outside, tallest * BallManager.LAYER_HEIGHT])

	_check("6", "only Level 1 starts unlocked", GameState.unlocked[0] and GameState.unlocked.count(true) == 1)
	await _frames(3)
	_check("7", "HUD shows the counts", hud.balls_left_text() == "234,000" and hud.level_text() == "LEVEL 1 / 6   PLAYROOM"
		and hud.tank_text() == "0 / 50,000" and hud.deposited_text() == "0",
		"%s | %s | %s" % [hud.balls_left_text(), hud.level_text(), hud.tank_text()])
	var dot := hud.dot()
	var centre := get_viewport().get_visible_rect().size * 0.5
	_check("8", "centre dot: white, 3 px, 35 %, exactly centred",
		dot.visible and is_equal_approx(dot.diameter(), 3.0) and dot.color().is_equal_approx(Color(1, 1, 1, 0.35)) and dot.global_position.distance_to(centre) < 0.01,
		"at %s of %s" % [dot.global_position, centre * 2.0])


func _test_movement() -> void:
	var start := level.spawn_point()
	await _until(player.is_on_floor, 1.0)
	_check("9", "player spawns on the floor of Level 1", player.is_on_floor() and _flat(player.global_position).distance_to(_flat(start)) < 0.05 and absf(player.global_position.y) < 0.02,
		"at %s" % player.global_position)

	var yaw_before := player.yaw
	_mouse(Vector2(120, -40))
	await _frames(3)
	var per_pixel: float = Player.LOOK_PER_PIXEL * Settings.get_value("camera", "mouse_sensitivity")
	_check("10", "mouse turns the camera", absf(player.yaw - yaw_before + 120 * per_pixel) < 0.001 and absf(player.pitch - 40 * per_pixel) < 0.001,
		"yaw %+.3f rad, pitch %+.3f rad" % [player.yaw - yaw_before, player.pitch])

	player.teleport(start, 0.0)
	await _frames(3)
	Input.action_press("move_forward")
	await _seconds(0.1)
	var easing := _flat_speed()
	await _seconds(0.4)
	var walk := _flat_speed()
	Input.action_release("move_forward")
	await _seconds(0.05)
	var slowing := _flat_speed()
	await _seconds(0.3)
	_check("11", "W walks at 5 m/s, easing in and out", absf(walk - 5.0) < 0.05 and easing > 1.0 and easing < 4.9 and slowing > 0.5 and slowing < 4.9 and _flat_speed() < 0.05,
		"%.2f m/s after 0.1 s, %.2f m/s walking, %.2f m/s 0.05 s after release" % [easing, walk, slowing])

	player.teleport(start, 0.0)
	await _frames(3)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(0.5)
	var sprint := _flat_speed()
	_release_all()
	await _seconds(0.4)
	_check("12", "Shift sprints at 8 m/s", absf(sprint - 8.0) < 0.05, "%.2f m/s" % sprint)

	player.teleport(start, 0.0)
	await _until(player.is_on_floor, 1.0)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var apex := 0.0
	for i in 70:
		apex = maxf(apex, player.global_position.y - start.y)
		await get_tree().physics_frame
	_check("13", "Space jumps about 1 m and lands", apex > 0.9 and apex < 1.15 and player.is_on_floor(), "apex %.2f m" % apex)

	var before := player.steps_played
	player.teleport(start, 0.0)
	await _until(player.is_on_floor, 1.0)
	Input.action_press("move_forward")
	await _seconds(1.0)
	var walked := player.steps_played - before
	_release_all()
	await _seconds(0.4)
	var stood := player.steps_played
	await _seconds(0.5)
	var still := player.steps_played == stood
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_press("move_forward")
	var air_steps := 0
	var last := player.steps_played
	for i in 40:
		await get_tree().physics_frame
		if not player.is_on_floor() and player.steps_played > last:
			air_steps += 1
		last = player.steps_played
	_release_all()
	_check("14", "footsteps on the ground only", walked >= 2 and still and air_steps == 0, "%d steps in 1 s of walking" % walked)


func _test_collisions() -> void:
	# Walk into the north wall.
	player.teleport(Vector3(3.0, 0.05, -12.0), 0.0)
	await _until(player.is_on_floor, 1.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.5)
	_release_all()
	var at_wall := player.global_position.z
	_check("15", "walls stop the player", at_wall > -level.DEPTH * 0.5 + 0.3 and at_wall < -level.DEPTH * 0.5 + 0.45, "stopped %.2f m from the wall face" % (at_wall + level.DEPTH * 0.5))

	# Walk into a pillar.
	var pillar: Vector2 = level.PILLARS[1]
	player.teleport(Vector3(pillar.x, 0.05, pillar.y + 3.0), 0.0)
	await _until(player.is_on_floor, 1.0)
	Input.action_press("move_forward")
	await _seconds(1.5)
	_release_all()
	_check("16", "pillars stop the player", player.global_position.z > pillar.y + level.PILLAR * 0.5 + 0.3, "stopped at z %.2f, pillar face at %.2f" % [player.global_position.z, pillar.y + level.PILLAR * 0.5])

	# Run and jump at the pit from the south: onto the kerb, never into the pit.
	player.teleport(Vector3(1.0, 0.05, 7.0), 0.0)
	await _until(player.is_on_floor, 1.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var lowest := 1.0
	var furthest := 99.0
	for i in 150:
		if i % 20 == 5:
			Input.action_press("jump")
		elif i % 20 == 8:
			Input.action_release("jump")
		await get_tree().physics_frame
		lowest = minf(lowest, player.global_position.y)
		furthest = minf(furthest, player.global_position.z)
	_release_all()
	await _seconds(0.3)
	_check("17", "the player cannot fall into the pit", lowest > -0.05 and furthest > level.PIT.end.y + 0.3,
		"closest %.2f m from the opening, lowest y %.2f" % [furthest - level.PIT.end.y, lowest])

	# The door to Level 2 is shut.
	player.teleport(Vector3(16.0, 0.05, 0.0), -PI * 0.5)
	await _until(player.is_on_floor, 1.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.5)
	_release_all()
	_check("18", "the Level 2 door is shut", player.global_position.x < level.WIDTH * 0.5 - 0.3, "stopped at x %.2f" % player.global_position.x)


func _test_vacuum() -> void:
	# Stand south of the largest mound and aim at it.
	var pile: Vector4 = level.PILES[0]
	var stand := Vector3(pile.x, 0.05, pile.y + 3.6)
	player.teleport(stand, 0.0)
	await _until(player.is_on_floor, 1.0)
	_aim_at(Vector3(pile.x, 0.5, pile.y))
	await _frames(2)

	# Looking at the ceiling collects nothing.
	var before := balls.count()
	player.set_look(0.0, 0.9)
	Input.action_press("vacuum")
	await _seconds(0.8)
	Input.action_release("vacuum")
	_check("19", "the motor runs but takes nothing when aimed away from balls", balls.count() == before and player.vacuum.power > 0.9 and GameState.vacuum_stored == 0,
		"power %.2f" % player.vacuum.power)
	await _seconds(1.0)
	_check("20", "releasing the button stops the motor", player.vacuum.power == 0.0)

	_aim_at(Vector3(pile.x, 0.5, pile.y))
	Input.action_press("vacuum")
	await _seconds(0.5)             # spin-up
	var at_speed := balls.count()
	var in_flight := 0
	var seen_sucking := false
	for i in 60:
		await get_tree().physics_frame
		in_flight = maxi(in_flight, game.flyers.active())
		seen_sucking = seen_sucking or player.vacuum.sucking
	var rate := at_speed - balls.count()
	Input.action_release("vacuum")
	var taken := before - balls.count()
	_check("21", "holding left mouse collects balls from the pile", taken > 80 and GameState.vacuum_stored == taken and GameState.remaining[0] == balls.count(),
		"%d collected, %d left in the level" % [taken, balls.count()])
	_check("22", "collection rate at full power is 280 balls a second", absi(rate - 280) <= 40, "%d in one second" % rate)
	_check("23", "collected balls fly to the nozzle", in_flight > 8 and seen_sucking, "up to %d in the air at once" % in_flight)
	_check("24", "no ball is lost or invented", GameState.balls_in_run() == START_BALLS, "%d in the run" % GameState.balls_in_run())

	await _until(func() -> bool: return not balls.settling(), 4.0)
	var problem := balls.validate()
	_check("25", "the dug pile slides back to a stable slope", problem == "" and balls.steepest_step() < BallManager.SLOPE and not balls.settling(),
		problem if problem != "" else "steepest step %d ball(s)" % balls.steepest_step())
	await _frames(3)
	_check("26", "HUD follows the collection", hud.balls_left_text() == Hud.number(START_BALLS - taken) and hud.tank_text() == "%s / 50,000" % Hud.number(taken),
		"%s left, tank %s" % [hud.balls_left_text(), hud.tank_text()])

	var settled := balls.count()
	await _seconds(0.7)
	_check("27", "nothing is collected after release", balls.count() == settled and not player.vacuum.sucking)


func _test_capacity() -> void:
	# Shortcut: put the tank 50 balls short of full instead of vacuuming 49,000 balls here.
	_extra = 49950 - GameState.vacuum_stored
	GameState.store_in_vacuum(_extra)
	_filled_signals = 0
	var pile: Vector4 = level.PILES[1]
	player.teleport(Vector3(pile.x, 0.05, pile.y + 3.6), 0.0)
	await _until(player.is_on_floor, 1.0)
	_aim_at(Vector3(pile.x, 0.5, pile.y))
	var before := balls.count()
	Input.action_press("vacuum")
	await _seconds(2.0)
	var taken := before - balls.count()
	_check("28", "the vacuum stops at exactly 50,000", GameState.vacuum_stored == 50000 and taken == 50 and GameState.vacuum_full(),
		"took %d, tank %d" % [taken, GameState.vacuum_stored])
	await _frames(3)
	_check("29", "VACUUM FULL! is shown and the warning fires once", hud.full_warning_visible() and _filled_signals == 1, "%d signal(s)" % _filled_signals)
	var held := balls.count()
	await _seconds(1.0)
	Input.action_release("vacuum")
	_check("30", "a full vacuum collects nothing more", balls.count() == held and GameState.vacuum_stored == 50000)


func _test_unload() -> void:
	# Far from the pit, E does nothing.
	Input.action_press("unload")
	await _seconds(0.5)
	Input.action_release("unload")
	_check("31", "E does nothing away from the pit", GameState.deposited == 0 and not pit.can_unload() and not hud.prompt_visible())

	player.teleport(Vector3(0.0, 0.05, 5.0), 0.0)
	await _until(player.is_on_floor, 1.0)
	player.set_look(0.0, -0.7)
	await _frames(4)
	_check("32", "the prompt appears when looking into the pit", pit.player_in_range and pit.can_unload() and hud.prompt_visible())

	var level_before := pit.surface_height()
	Input.action_press("unload")
	await _frames(2)
	var counted_from := GameState.deposited
	var in_flight := 0
	var was_unloading := false
	for i in 60:
		await get_tree().physics_frame
		in_flight = maxi(in_flight, game.flyers.active())
		was_unloading = was_unloading or pit.unloading
	var rate := GameState.deposited - counted_from
	Input.action_release("unload")
	await _frames(3)
	var partial := GameState.deposited
	_check("33", "holding E unloads 8,000 balls a second", absi(rate - 8000) <= 160 and was_unloading and GameState.vacuum_stored == 50000 - partial,
		"%d in one second" % rate)
	_check("34", "balls pour into the pit", in_flight > 40, "up to %d in the air at once" % in_flight)
	await _seconds(0.5)
	_check("35", "releasing E keeps pouring", GameState.deposited > partial and pit.unloading,
		"%d deposited, %d still in the tank" % [GameState.deposited, GameState.vacuum_stored])

	Input.action_press("unload")
	var emptied: bool = await _until(func() -> bool: return GameState.vacuum_stored == 0, 8.0)
	Input.action_release("unload")
	await _frames(3)
	_check("36", "a full tank empties completely", emptied and GameState.deposited == 50000 and not hud.full_warning_visible() and not hud.prompt_visible(),
		"deposited %d" % GameState.deposited)
	_check("37", "the pit fills as balls are deposited", pit.surface_height() > level_before + 0.15 and absf(pit.fill_fraction() - 50000.0 / (START_BALLS + _extra)) < 0.0001,
		"surface rose %.2f m, %.1f %% of the run deposited" % [pit.surface_height() - level_before, pit.fill_fraction() * 100.0])
	_check("38", "counts still add up", GameState.balls_in_run() == START_BALLS + _extra and hud.deposited_text() == "50,000",
		"%d in the run (%d of them conjured by test 28)" % [GameState.balls_in_run(), _extra])

	# And the vacuum works again.
	var pile: Vector4 = level.PILES[2]
	player.teleport(Vector3(pile.x, 0.05, pile.y + 3.2), 0.0)
	await _until(player.is_on_floor, 1.0)
	_aim_at(Vector3(pile.x, 0.4, pile.y))
	var before := balls.count()
	Input.action_press("vacuum")
	await _seconds(1.0)
	Input.action_release("vacuum")
	_check("39", "the emptied vacuum collects again", balls.count() < before - 300 and GameState.vacuum_stored == before - balls.count(), "%d collected" % (before - balls.count()))
	await _seconds(0.8)


func _test_settings() -> void:
	var camera := player.camera
	Settings.set_value("camera", "fov", 110.0)
	await _seconds(1.0)
	var wide := camera.fov
	var slider: HSlider = menu.controls["camera/fov"]
	slider.value = 72.0
	await _seconds(1.0)
	_check("40", "field of view applies at once, from code and from the menu slider", absf(wide - 110.0) < 0.2 and absf(camera.fov - 72.0) < 0.2 and is_equal_approx(Settings.get_value("camera", "fov"), 72.0),
		"%.1f then %.1f" % [wide, camera.fov])
	Settings.set_value("camera", "fov", 500.0)
	_check("41", "field of view stays inside 60 to 120", is_equal_approx(Settings.get_value("camera", "fov"), 120.0))

	Settings.set_value("camera", "mouse_sensitivity", 1.0)
	var yaw_before := player.yaw
	_mouse(Vector2(100, 0))
	await _frames(3)
	_check("42", "mouse sensitivity scales the look speed", absf(player.yaw - yaw_before + 100 * Player.LOOK_PER_PIXEL) < 0.001, "%.3f rad for 100 px" % (yaw_before - player.yaw))

	var dot := hud.dot()
	Settings.set_value("camera", "dot_size", 8.0)
	Settings.set_value("camera", "dot_opacity", 0.9)
	Settings.set_value("camera", "dot_color", Color(1, 0, 0))
	var restyled := is_equal_approx(dot.diameter(), 8.0) and dot.color().is_equal_approx(Color(1, 0, 0, 0.9))
	Settings.set_value("camera", "dot_visible", false)
	var hidden := not dot.visible
	_check("43", "centre dot size, opacity, colour and visibility apply", restyled and hidden)

	var bus := AudioServer.get_bus_index("Vacuum")
	Settings.set_value("audio", "vacuum", 0.25)
	var quiet := absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.01 and not AudioServer.is_bus_mute(bus)
	Settings.set_value("audio", "vacuum", 0.0)
	var muted := AudioServer.is_bus_mute(bus)
	Settings.set_value("audio", "master", 0.5)
	var master := absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01
	var buses := 0
	for bus_name: String in Sfx.BUSES:
		if AudioServer.get_bus_index(bus_name) > 0 and AudioServer.get_bus_send(AudioServer.get_bus_index(bus_name)) == &"Master":
			buses += 1
	_check("44", "volume sliders drive their own audio buses", quiet and muted and master and buses == Sfx.BUSES.size(), "%d buses feeding Master" % buses)

	var window := get_window()
	var environment := level.environment()
	Settings.set_value("graphics", "shadows", Settings.Shadows.OFF)
	var none := level.shadow_lights()
	Settings.set_value("graphics", "shadows", Settings.Shadows.LOW)
	var few := level.shadow_lights()
	Settings.set_value("graphics", "shadows", Settings.Shadows.HIGH)
	var all := level.shadow_lights()
	Settings.set_value("graphics", "ambient_occlusion", false)
	var ao_off := not environment.ssao_enabled
	Settings.set_value("graphics", "ambient_occlusion", true)
	_check("45", "shadow and ambient occlusion settings apply", none == 0 and few == 4 and all == 12 and ao_off and environment.ssao_enabled,
		"%d / %d / %d lights casting shadows" % [none, few, all])

	Settings.set_value("graphics", "anti_aliasing", Settings.AntiAliasing.FXAA)
	var fxaa := window.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA and window.msaa_3d == Viewport.MSAA_DISABLED
	Settings.set_value("graphics", "anti_aliasing", Settings.AntiAliasing.MSAA_4X)
	var msaa := window.msaa_3d == Viewport.MSAA_4X and window.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED
	Settings.set_value("graphics", "anti_aliasing", Settings.AntiAliasing.TAA)
	var taa := window.use_taa and window.msaa_3d == Viewport.MSAA_DISABLED
	Settings.set_value("graphics", "render_scale", 0.6)
	var scaled := is_equal_approx(window.scaling_3d_scale, 0.6)
	Settings.set_value("graphics", "fps_cap", 90)
	var capped := Engine.max_fps == 90
	Settings.set_value("graphics", "vsync", false)
	var vsync_off := DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED or DisplayServer.get_name() == "headless"
	_check("46", "anti-aliasing, render scale, FPS cap and VSync apply", fxaa and msaa and taa and scaled and capped and vsync_off)

	Settings.set_value("graphics", "quality", Settings.Quality.LOW)
	var low := level.shadow_lights() == 0 and not environment.ssao_enabled and not environment.ssr_enabled and is_equal_approx(window.scaling_3d_scale, 0.75)
	var choice: OptionButton = menu.controls["graphics/shadows"]
	var menu_follows := choice.selected == 0
	Settings.set_value("graphics", "quality", Settings.Quality.ULTRA)
	var ultra := level.shadow_lights() == 12 and environment.ssao_enabled and environment.ssr_enabled and window.msaa_3d == Viewport.MSAA_4X
	_check("47", "quality presets set the detailed options, and the menu follows", low and ultra and menu_follows)

	# Saved to disk and read back, clamped, with defaults for anything missing.
	Settings.set_value("camera", "fov", 101.0)
	Settings.save()
	var file := ConfigFile.new()
	var saved := file.load(Settings.path) == OK and is_equal_approx(file.get_value("camera", "fov"), 101.0) and not file.has_section("run")
	file.set_value("camera", "fov", 999.0)
	file.set_value("camera", "head_bob", "yes")
	file.erase_section_key("audio", "master")
	file.save(Settings.path)
	Settings.reset_section("camera")
	Settings.set_value("audio", "master", 0.1)
	Settings.load_file()
	_check("48", "settings persist in their own file and bad values are rejected",
		saved and is_equal_approx(Settings.get_value("camera", "fov"), 120.0) and Settings.get_value("camera", "head_bob") == true and is_equal_approx(Settings.get_value("audio", "master"), 0.1),
		Settings.path)

	for section: String in Settings.DEFAULTS:
		Settings.reset_section(section)
	await _frames(3)
	_check("49", "Restore Defaults puts everything back", is_equal_approx(Settings.get_value("camera", "fov"), 90.0) and dot.visible and is_equal_approx(dot.diameter(), 3.0)
		and level.shadow_lights() == 12 and window.msaa_3d == Viewport.MSAA_2X and Engine.max_fps == 0)


func _test_pause() -> void:
	game.set_paused(true)
	var clock := GameState.run_time
	var before := balls.count()
	Input.action_press("vacuum")
	Input.action_press("move_forward")
	var at := player.global_position
	await _seconds(0.6)
	_release_all()
	_check("50", "Esc pauses: clock, player and vacuum all stop", get_tree().paused and menu.visible and GameState.run_time == clock and balls.count() == before and player.global_position == at)

	menu.open_settings()
	var on_settings := menu.showing_settings()
	_key("pause")
	await _frames(2)
	var back := menu.visible and not menu.showing_settings() and get_tree().paused
	_key("pause")
	await _frames(2)
	_check("51", "Esc steps back out of settings, then resumes", on_settings and back and not get_tree().paused and not menu.visible)
	await _seconds(0.2)
	_check("52", "the run clock continues after resuming", GameState.run_time > clock)


func _test_unlock_and_restart() -> void:
	# Shortcut: empty the level in one call instead of vacuuming the rest of it.
	balls.clear_all()
	await _frames(3)
	_check("53", "clearing Level 1 unlocks Level 2", GameState.remaining[0] == 0 and GameState.unlocked[1] and not GameState.unlocked[2] and hud.toast_text().begins_with("LEVEL 1 COMPLETED"),
		hud.toast_text())

	Settings.set_value("camera", "fov", 77.0)
	game.set_paused(true)
	var restarts: Array[int] = [0]
	menu.restart_pressed.connect(func() -> void: restarts[0] += 1)
	menu._restart.pressed.emit()
	var first: int = restarts[0]
	menu._restart.pressed.emit()
	await _frames(5)
	_check("54", "Restart Run needs two presses", first == 0 and restarts[0] == 1)
	var problem := balls.validate()
	_check("55", "restart restores the run", problem == "" and balls.count() == 4000 and balls.layout_hash() == _start_layout and GameState.balls_in_run() == START_BALLS
		and GameState.vacuum_stored == 0 and GameState.deposited == 0 and not GameState.unlocked[1] and GameState.run_time < 0.2
		and _flat(player.global_position).distance_to(_flat(level.spawn_point())) < 0.05 and not get_tree().paused,
		"%d balls, same layout as the first start: %s" % [balls.count(), balls.layout_hash() == _start_layout])
	_check("56", "restart leaves the settings alone", is_equal_approx(Settings.get_value("camera", "fov"), 77.0))
	Settings.reset_section("camera")


# How long the scripted parts take. Not pass or fail, and only true for the machine that ran it.
func _report_costs() -> void:
	var began := Time.get_ticks_usec()
	balls.populate(4000, level.PILES, level.BALL_SEED)
	var fill_ms := (Time.get_ticks_usec() - began) / 1000.0
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	var pile: Vector4 = level.PILES[0]
	var origin := Vector3(pile.x, 1.65, pile.y + 3.6)
	var direction := (Vector3(pile.x, 0.5, pile.y) - origin).normalized()
	began = Time.get_ticks_usec()
	var ticks := 60
	for i in ticks:
		balls.suck(origin, direction, 4.5, 20, positions, colors)
		balls._settle(BallManager.SETTLE_BUDGET)
	var tick_ms := (Time.get_ticks_usec() - began) / 1000.0 / ticks
	print("cost  filling Level 1 with 20,000 balls: %.0f ms" % fill_ms)
	print("cost  one physics tick of suction (20 balls) plus pile sliding: %.2f ms of 16.67 ms" % tick_ms)
	print("cost  memory in use by the engine: %.0f MB" % (OS.get_static_memory_usage() / 1048576.0))


# ---------------------------------------------------------------- screenshots and frame time

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_use_window()
	_use_scale()
	# Give the reflection probe and the texture streaming a moment.
	for i in 90:
		await get_tree().process_frame
	var pile: Vector4 = level.PILES[0]

	player.teleport(level.spawn_point(), 0.0)
	player.set_look(0.0, -0.1)
	await _snap(dir, "01_spawn")

	player.teleport(Vector3(-17.0, 0.05, 12.5), 0.0)
	player.set_look(-0.95, -0.12)
	await _snap(dir, "02_hall_from_corner")

	player.teleport(Vector3(pile.x + 0.6, 0.05, pile.y + 3.6), 0.0)
	_aim_at(Vector3(pile.x, 0.45, pile.y))
	await _snap(dir, "03_pile")

	Input.action_press("vacuum")
	await get_tree().create_timer(0.9).timeout
	await _snap(dir, "04_vacuuming")
	await get_tree().create_timer(1.2).timeout
	await _snap(dir, "05_pile_dug_out")
	Input.action_release("vacuum")

	player.teleport(Vector3(3.2, 0.05, 4.7), 0.0)
	_aim_at(Vector3(0.0, -1.3, 0.0))
	GameState.store_in_vacuum(46000)
	await get_tree().create_timer(0.3).timeout
	Input.action_press("unload")
	await get_tree().create_timer(2.2).timeout
	await _snap(dir, "06_unloading")
	await get_tree().create_timer(4.5).timeout
	Input.action_release("unload")
	await get_tree().create_timer(0.8).timeout
	await _snap(dir, "07_pit_after_unload")

	player.teleport(Vector3(13.5, 0.05, 0.0), -PI * 0.5)
	player.set_look(-PI * 0.5, 0.16)
	await _snap(dir, "08_level_2_door")

	player.teleport(Vector3(-2.0, 0.05, -12.0), PI)
	player.set_look(PI + 0.25, 0.42)
	await _snap(dir, "09_ceiling")

	player.teleport(Vector3(9.0, 0.05, 4.4), 0.0)
	_aim_at(Vector3(10.0, 0.2, 2.4))
	await _snap(dir, "10_floor_close")

	GameState.store_in_vacuum(GameState.vacuum_space())
	player.teleport(level.spawn_point(), 0.0)
	player.set_look(0.35, -0.2)
	await get_tree().create_timer(0.4).timeout
	await _snap(dir, "11_vacuum_full")

	game.set_paused(true)
	await _snap(dir, "12_pause_menu")
	menu.open_settings()
	await _snap(dir, "13_settings")
	game.set_paused(false)

	await _frame_times()


# Frame time with the frame cap and VSync off, in three situations.
func _frame_times() -> void:
	game.restart_run()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window := get_window().size
	print("frame time on %s, window %d x %d, quality %s" % [RenderingServer.get_video_adapter_name(),
		window.x, window.y, ["Low", "Medium", "High", "Ultra"][Settings.get_value("graphics", "quality")]])
	var pile: Vector4 = level.PILES[0]

	player.teleport(level.spawn_point(), 0.0)
	player.set_look(0.0, -0.1)
	await _measure("standing at the spawn point, whole hall in view")

	player.teleport(Vector3(-17.0, 0.05, 12.5), 0.0)
	player.set_look(-0.95, -0.12)
	await _measure("corner view, most of the 20,000 balls in view")

	player.teleport(Vector3(pile.x, 0.05, pile.y + 3.6), 0.0)
	_aim_at(Vector3(pile.x, 0.45, pile.y))
	Input.action_press("vacuum")
	await _measure("vacuuming the largest pile")
	Input.action_release("vacuum")
	print("memory: %.0f MB engine, %.0f MB video" % [OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])


## `--perf`: what each graphics feature costs, measured from the spawn point with one thing changed at a time.
func perf(p_game: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = p_game
	player = game.player
	balls = game.balls
	level = game.level
	player.require_mouse_capture = false
	_use_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_use_scale()
	for i in 90:
		await get_tree().process_frame
	var window := get_window()
	var environment := level.environment()
	print("feature costs on %s, window %d x %d" % [RenderingServer.get_video_adapter_name(), window.size.x, window.size.y])
	player.teleport(level.spawn_point(), 0.0)
	player.set_look(0.0, -0.1)
	await _measure("High preset as shipped", 200)

	Settings.set_value("graphics", "shadows", Settings.Shadows.LOW)
	await _measure("shadows Low (4 lights)", 200)
	Settings.set_value("graphics", "shadows", Settings.Shadows.OFF)
	await _measure("shadows Off", 200)
	Settings.set_value("graphics", "shadows", Settings.Shadows.HIGH)

	Settings.set_value("graphics", "ambient_occlusion", false)
	await _measure("ambient occlusion off", 200)
	Settings.set_value("graphics", "ambient_occlusion", true)

	environment.ssr_enabled = false
	await _measure("screen-space reflections off", 200)
	environment.ssr_enabled = true

	Settings.set_value("graphics", "anti_aliasing", Settings.AntiAliasing.OFF)
	await _measure("anti-aliasing off", 200)
	Settings.set_value("graphics", "anti_aliasing", Settings.AntiAliasing.FXAA)
	await _measure("anti-aliasing FXAA", 200)
	Settings.set_value("graphics", "anti_aliasing", Settings.AntiAliasing.MSAA_2X)

	environment.glow_enabled = false
	await _measure("glow off", 200)
	environment.glow_enabled = true
	environment.fog_enabled = false
	await _measure("fog off", 200)
	environment.fog_enabled = true

	balls.visible = false
	await _measure("balls hidden", 200)
	balls.visible = true

	var scale: float = Settings.get_value("graphics", "render_scale")
	for quality in 4:
		Settings.set_value("graphics", "quality", quality)
		Settings.set_value("graphics", "render_scale", scale)
		await _measure("preset %s (at the same render scale)" % ["Low", "Medium", "High", "Ultra"][quality], 200)
	get_tree().quit()


func _measure(what: String, frames := 360) -> void:
	for i in 60:
		await get_tree().process_frame
	# Note: a window on macOS is held to the display rate whatever the VSync setting says, so readings above
	# that rate need `--native` (full screen).
	var times := PackedFloat32Array()
	var triangles := 0.0
	var undrawn := 0
	var last := Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		triangles = maxf(triangles, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if not DisplayServer.window_can_draw():
			undrawn += 1
	# A hidden window (another app in front in full screen, a locked screen) is not drawn at all, and the
	# engine then idles at a fixed pace that looks like a very good frame rate. That is not a reading.
	if undrawn > 0:
		print("  %-48s NOT MEASURED: the window was not on screen for %d of %d frames" % [what, undrawn, frames])
		return
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	var mean := total / times.size()
	var slow := times[int(times.size() * 0.99)]
	var size := get_window().size
	var scale := get_viewport().scaling_3d_scale
	print("  %-48s %5.2f ms a frame (%3.0f fps), slowest 1 %% %5.2f ms (%3.0f fps), 3D at %d x %d, %.1f M triangles" % [what, mean, 1000.0 / mean, slow, 1000.0 / slow,
		roundi(size.x * scale), roundi(size.y * scale), triangles / 1000000.0])


func _snap(dir: String, shot: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [dir, shot])
	print("saved %s/%s.png" % [dir, shot])


# ---------------------------------------------------------------- helpers

# `--scale=0.5` sets the render scale for a screenshot or timing run.
func _use_scale() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scale="):
			Settings.set_value("graphics", "render_scale", arg.trim_prefix("--scale=").to_float())


# A 1920 x 1080 window, so readings compare between machines. `--native` keeps the full screen instead.
func _use_window() -> void:
	var window := get_window()
	if OS.get_cmdline_user_args().has("--native"):
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1920, 1080)
	window.position = DisplayServer.screen_get_usable_rect(window.current_screen).position + Vector2i(40, 60)


func _check(number: String, what: String, passed: bool, detail := "") -> void:
	if not passed:
		_failed += 1
	var line := "%s  %-3s %s" % ["PASS" if passed else "FAIL", number, what]
	print(line if detail == "" else "%s  [%s]" % [line, detail])


# Turn the player to look straight at a point in the world.
func _aim_at(target: Vector3) -> void:
	var eye := player.global_position + Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	var to := target - eye
	player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _mouse(moved: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = moved
	motion.screen_relative = moved
	Input.parse_input_event(motion)


func _key(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _until(condition: Callable, timeout: float) -> bool:
	for i in roundi(timeout * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _release_all() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)


func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


func _flat_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()
