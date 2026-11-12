# Developer tool, not part of the game. Plays Level 1 by itself and reports what works.
#
#   Godot --headless --fixed-fps 60 --path games/dont-touch-the-grass -- --playtest
#
# It presses the real input actions (move_forward, jump, sprint), so it tests the same code a person drives.
# The numbers in front of each line match the Phase 1 test list. Ends with `playtest ok` or `playtest fail`.
#
#   Godot --path games/dont-touch-the-grass --windowed --resolution 1280x720 -- --shots=/some/folder
#
# saves screenshots instead (needs a real window, so no --headless).
extends Node

const EnemyScript = preload("res://scripts/enemies/enemy.gd")
const GrassScript = preload("res://scripts/level/grass_field.gd")

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]

var game: Node3D
var player: CharacterBody3D
var ant: CharacterBody3D
var _failed := 0
var _spoken: Array[String] = []
var _narrator_busy := false
var _narrator_overlap := false
var _completions := 0
var _safety_frame := -1
var _ended_frame := -1
var _states: Array[int] = []


func run(p_game: Node3D, shots_dir: String) -> void:
	game = p_game
	player = game.player
	ant = game.level.enemies[0]
	if shots_dir != "":
		await _shots(shots_dir)
		get_tree().quit()
		return
	game.hold_level = true
	game.narrator.line_started.connect(_on_line_started)
	game.narrator.line_finished.connect(func(_id: String) -> void: _narrator_busy = false)
	game.level_completed.connect(func(_number: int) -> void: _completions += 1)
	game.chase.reached_safety.connect(func() -> void: _safety_frame = Engine.get_physics_frames())
	game.chase.chase_ended.connect(func() -> void: _ended_frame = Engine.get_physics_frames())
	_bind_ant()
	await _frames(5)
	await _test_start()
	await _test_movement()
	await _test_route()
	await _test_chase()
	await _test_death()
	await _test_ui_and_narrator()
	await _test_escape_and_audio()
	await _test_pause_and_keys()
	await _test_all_levels()
	print("playtest ok" if _failed == 0 else "playtest fail (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


# ---------------------------------------------------------------- tests

func _test_start() -> void:
	var platforms: Array = game.level.platforms
	_check("1-2", "project starts, Level 1 scene is built", game.level != null and platforms.size() >= 6 and ant != null,
		"%d platforms, %d grass blades, %d ceiling lights" % [platforms.size(), game.level.grass.blade_count, game.level.room.lights.size()])
	var polygons: int = game.level.nav_region.navigation_mesh.get_polygon_count()
	_check("nav", "monster navigation map exists", polygons > 0, "%d polygons" % polygons)
	_check("calm", "the level starts with no chase running", not game.chase.chase_active and not game.chase.player_in_danger)
	game.begin()


func _test_movement() -> void:
	var start: Vector3 = game.level.start_position()
	await _until(player.is_on_floor, 1.0)

	var yaw_before: float = player.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120, -40)
	motion.screen_relative = Vector2(120, -40)
	Input.parse_input_event(motion)
	await _frames(3)
	var turned: float = player.yaw - yaw_before
	_check("3a", "mouse turns the camera", absf(turned + 120 * 0.0022) < 0.01 and absf(player.pitch - 40 * 0.0022) < 0.01,
		"yaw %+.3f rad, pitch %+.3f rad" % [turned, player.pitch])

	player.teleport(start, game.level.start_yaw())
	await _frames(3)
	Input.action_press("move_forward")
	await _seconds(0.2)
	var walk := _flat_speed()
	var walked := _flat(player.global_position).distance_to(_flat(start))
	Input.action_release("move_forward")
	await _seconds(0.25)
	_check("3b", "W walks, releasing stops without sliding", absf(walk - 4.5) < 0.1 and walked > 0.5 and _flat_speed() < 0.05,
		"%.2f m/s walking, %.2f m/s after release" % [walk, _flat_speed()])

	player.teleport(start, game.level.start_yaw())
	await _frames(3)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(0.15)
	var sprint := _flat_speed()
	_release_all()
	await _seconds(0.25)
	_check("4", "Shift sprints", absf(sprint - 7.0) < 0.1, "%.2f m/s" % sprint)

	player.teleport(start, game.level.start_yaw())
	await _frames(3)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var apex := 0.0
	for i in 60:
		apex = maxf(apex, player.global_position.y - start.y)
		await get_tree().physics_frame
	_check("5", "Space jumps and lands", apex > 1.35 and apex < 1.65 and player.is_on_floor() and absf(player.global_position.y - start.y) < 0.02,
		"apex %.2f m" % apex)


func _test_route() -> void:
	var platforms: Array = game.level.platforms
	var one_pole := true
	var highest := 0.0
	var lowest_underside := 99.0
	for platform in platforms:
		var pole_bodies := 0
		for child in platform.get_children():
			if child is StaticBody3D:
				pole_bodies += 1
		one_pole = one_pole and pole_bodies == 1 and platform.poles.size() == 1
		highest = maxf(highest, platform.top)
		lowest_underside = minf(lowest_underside, platform.top - platform.UNDERSIDE_DROP)
	_check("7", "every platform has exactly one supporting pole", one_pole, "%d platforms" % platforms.size())
	_check("8", "platforms mix low and high tops", highest >= 1.6 and platforms[0].top <= 1.40, "tops up to %.2f m" % highest)
	_check("8b", "monsters fit under the lowest platform", lowest_underside > game.level.NAV_AGENT_HEIGHT,
		"lowest underside %.2f m, monster height %.2f m" % [lowest_underside, game.level.NAV_AGENT_HEIGHT])

	ant.frozen = true
	player.teleport(game.level.start_position(), game.level.start_yaw())
	await _until(player.is_on_floor, 1.0)
	var landed := 1
	var failed_at := ""
	for i in range(platforms.size() - 1):
		var ok: bool = await _hop(platforms[i], platforms[i + 1], i + 1 == platforms.size() - 1)
		if not ok:
			failed_at = "jump %d to %d from %s to %s player %s" % [i + 1, i + 2, platforms[i].top_center(), platforms[i + 1].top_center(), player.global_position]
			break
		landed += 1
	_release_all()
	_check("6", "all platforms hold the player", landed == platforms.size(), "landed on %d of %d" % [landed, platforms.size()])
	_check("9", "the whole route can be jumped, start to finish", failed_at == "", failed_at if failed_at != "" else "%d jumps" % (platforms.size() - 1))

	# The last hop walks onto the glowing pad.
	await _until(func() -> bool: return _completions > 0, 3.0)
	var phase_finishing: bool = game.phase == game.Phase.FINISHING
	await _until(func() -> bool: return game.phase == game.Phase.PLAYING, 5.0)
	await _seconds(0.5)
	_check("22", "the finish pad detects the player, once", _completions == 1 and phase_finishing and game.completed_levels == [1],
		"level_completed fired %d time(s)" % _completions)
	_bind_ant()
	ant.frozen = false


func _test_chase() -> void:
	var platforms: Array = game.level.platforms
	var hazard: Area3D = game.level.hazard
	var chase: Node = game.chase

	# 11. Left alone, the ant wanders and stays calm.
	var travelled := 0.0
	var last := ant.global_position
	for i in 60 * 10:
		await get_tree().physics_frame
		travelled += ant.global_position.distance_to(last)
		last = ant.global_position
	_check("11", "the ant roams while the player is safe", travelled > 3.0 and ant.state == EnemyScript.State.ROAMING and not chase.chase_active,
		"walked %.1f m in 10 s" % travelled)

	# 10 + 12. Open lawn in the middle, away from poles.
	var g1 := Vector2(0.0, 8.0)
	_place_ant(g1 + Vector2(2.4, 0.0))
	await _put_on_grass(g1)
	_check("10", "touching the grass is detected", hazard.player_inside and chase.player_in_danger)
	var gap_before := _ant_gap()
	await _seconds(0.6)
	_check("12", "touching the grass starts the chase", ant.state == EnemyScript.State.CHASING and _ant_gap() < gap_before - 0.3,
		"ant closed %.1f m in 0.6 s" % (gap_before - _ant_gap()))

	# 13-15, 17. Escape onto platform 2 and wait.
	_safety_frame = -1
	_ended_frame = -1
	await _put_on_platform(platforms[1])
	await _until(func() -> bool: return _safety_frame > 0, 1.0)
	var searching: bool = ant.state == EnemyScript.State.SEARCHING
	await _seconds(2.5)
	_place_ant(Vector2(platforms[1].position.x, platforms[1].position.z))
	ant.frozen = true
	var under: bool = platforms[1].rect().grow(0.3).has_point(_flat(ant.global_position))
	_check("13", "the ant follows from below the platform", searching and under and ant.state == EnemyScript.State.SEARCHING,
		"%.2f m from the player's feet, measured flat" % _ant_gap())
	var closest := _ant_gap()
	await _seconds(1.5)
	closest = minf(closest, _ant_gap())
	_check("14", "the ant cannot attack a player on a platform", game.deaths == 0 and game.phase == game.Phase.PLAYING and closest < ant.catch_radius + 0.3,
		"stood %.2f m away (it kills at %.2f m on grass) and nothing happened" % [closest, ant.catch_radius])
	ant.frozen = false
	await _until(func() -> bool: return _ended_frame > 0, 3.0)
	var waited := float(_ended_frame - _safety_frame) / Engine.physics_ticks_per_second
	_check("15", "the chase lasts 5 seconds after reaching safety", absf(waited - 5.0) < 0.04, "%.3f s" % waited)
	_check("17", "after 5 safe seconds the ant roams again", ant.state == EnemyScript.State.ROAMING and not chase.chase_active)

	# 16. Touch the grass again at 3 s: the countdown must start over.
	_place_ant(g1 + Vector2(2.4, 0.0))
	await _put_on_grass(g1)
	_safety_frame = -1
	_ended_frame = -1
	await _put_on_platform(platforms[1])
	await _until(func() -> bool: return _safety_frame > 0, 1.0)
	var first_safety := _safety_frame
	await _seconds(3.0)
	await _put_on_grass(g1 + Vector2(3.0, 2.0))
	await _frames(2)
	var chasing_again: bool = ant.state == EnemyScript.State.CHASING and chase.time_left() == 0.0 and chase.player_in_danger
	_safety_frame = -1
	await _put_on_platform(platforms[0])
	await _until(func() -> bool: return _safety_frame > 0, 1.0)
	var second_safety := _safety_frame
	await _until(func() -> bool: return _ended_frame > 0, 7.0)
	var second_wait := float(_ended_frame - second_safety) / Engine.physics_ticks_per_second
	var total := float(_ended_frame - first_safety) / Engine.physics_ticks_per_second
	_check("16", "touching the grass again resets the 5 seconds", chasing_again and absf(second_wait - 5.0) < 0.04 and total > 8.0,
		"second countdown %.3f s; %.2f s since the first landing" % [second_wait, total])


func _test_death() -> void:
	# 18. Stand on the grass and let it come.
	var g1 := Vector2(0.0, 8.0)
	_place_ant(g1 + Vector2(0.8, 0.0))
	await _put_on_grass(g1)
	var caught: bool = await _until(func() -> bool: return game.phase == game.Phase.DYING, 4.0)
	_check("18", "being caught on the grass triggers the jumpscare", caught and game.jumpscare.running and player.locked,
		"deaths %d" % game.deaths)
	# 19. Report the catch again, three ways, in the middle of the jumpscare.
	await _seconds(0.3)
	var lunged: float = ant.mouth_position().distance_to(player.cam.global_position)
	ant.caught_player.emit(ant)
	game._on_enemy_caught(ant)
	ant.caught_player.emit(ant)
	_check("19", "extra catch reports during the jumpscare are ignored", game.deaths == 1 and game.phase == game.Phase.DYING)
	await _seconds(0.3)
	_check("18b", "the ant's face is at the camera", ant.mouth_position().distance_to(player.cam.global_position) < 1.6 and lunged < 2.5,
		"%.2f m from the lens" % ant.mouth_position().distance_to(player.cam.global_position))

	# 20. Back at the start, in control, ant calm.
	await _until(func() -> bool: return game.phase == game.Phase.PLAYING, 5.0)
	var start: Vector3 = game.level.start_position()
	var at_start := _flat(player.global_position).distance_to(_flat(start)) < 0.05
	var ant_home: bool = ant.global_position.distance_to(ant.home) < 0.5 and ant.state == EnemyScript.State.ROAMING and not ant.frozen
	var calm: bool = not game.chase.chase_active and not game.chase.player_in_danger
	Input.action_press("move_forward")
	await _seconds(0.15)
	var moves := _flat_speed() > 3.0
	_release_all()
	await _seconds(0.3)
	_check("20", "the player respawns at the start of Level 1", at_start and not player.locked and moves and ant_home and calm and game.deaths == 1 and game.level_number == 1,
		"at start %s, controls %s, ant reset %s, chase cleared %s" % [at_start, moves, ant_home, calm])


func _test_ui_and_narrator() -> void:
	_check("21", "the level counter reads LEVEL 1/50", game.hud.level_text() == "LEVEL 1/50", game.hud.level_text())
	await _seconds(2.0)
	var wanted := ["intro", "grass", "death"]
	var missing: Array[String] = []
	for event: String in wanted:
		if not _spoken.has(event):
			missing.append(event)
	_check("23", "narrator events fire, one line at a time", missing.is_empty() and not _narrator_overlap and _spoken.has("intro"),
		"spoke: %s (sound muted in this test)" % ", ".join(_spoken))


func _test_escape_and_audio() -> void:
	_place_ant(Vector2(12.0, 10.0))
	var before: int = player.steps_played
	await _on_start_pad_rear()
	Input.action_press("move_forward")
	await _seconds(0.55)
	var walked: int = player.steps_played - before
	_release_all()
	await _seconds(0.4)
	var stood: int = player.steps_played
	await _seconds(0.4)
	var still: bool = player.steps_played == stood
	before = player.steps_played
	await _on_start_pad_rear()
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _seconds(0.52)
	var ran: int = player.steps_played - before
	_release_all()
	_check("steps", "footsteps while moving, faster when sprinting, silent when still", walked >= 2 and ran > walked and still,
		"walk %d, sprint %d" % [walked, ran])

	var air_before: int = player.steps_played
	player.teleport(game.level.start_position(), 0.0)
	await _frames(2)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	var air_steps := 0
	for i in 20:
		if not player.is_on_floor() and player.steps_played > air_before:
			air_steps += 1
		air_before = player.steps_played
		await get_tree().physics_frame
	_check("air", "no footsteps in the air", air_steps == 0)

	# Stand just south of the first platform and jump back onto it.
	_place_ant(Vector2(14.0, 10.0))
	await _put_on_grass(_grass_south_of(game.level.platforms[0]))
	await _seconds(0.35)
	_check("danger", "grass shows the danger effect and heartbeat", game.hud.danger() > 0.35 and game._heart.playing,
		"danger %.2f" % game.hud.danger())
	player.set_look(atan2(0.0, 1.0), 0.0)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	var back: bool = await _until(func() -> bool:
		return player.is_on_floor() and not game.level.hazard.player_inside and game.phase == game.Phase.PLAYING, 2.0)
	_release_all()
	await _seconds(0.6)
	_check("escape", "falling onto the grass can be jumped back from", back and game.deaths == 1 and game.hud.danger() < 0.08,
		"danger %.2f" % game.hud.danger())


func _test_pause_and_keys() -> void:
	var paused := false
	game.toggle_pause()
	paused = game.get_tree().paused and game.pause_menu.visible
	game.pause_menu.slider.value = 100
	var fov_ok: bool = is_equal_approx(player.fov, 100.0) and is_equal_approx(player.cam.fov, 100.0)
	game.toggle_pause()
	_check("pause", "ESC pause menu sets the field of view", paused and fov_ok and not game.get_tree().paused,
		"fov %.0f" % player.fov)

	game.set_look("outdoor")
	await _frames(4)
	_bind_ant()
	var outdoor: bool = game.look == "outdoor" and game.level.room.get_node_or_null("Sun") != null and game.level.room.get_node_or_null("Ceiling") == null
	game.set_look("dungeon")
	await _frames(4)
	_bind_ant()
	var dungeon: bool = game.look == "dungeon" and game.level.room.get_node_or_null("Sun") == null
	_check("look", "pause look can switch outdoor and dungeon", outdoor and dungeon)

	_place_ant(Vector2(14.0, 10.0))
	player.teleport(game.level.start_position(), 0.0)
	await _frames(2)
	await _tap("stream_push")
	var fell: bool = await _until(func() -> bool: return game.level.hazard.player_inside, 1.2)
	_check("F1", "F1 pushes the player off into the grass", fell)
	await _tap("stream_level_up")
	_check("F2", "F2 advances one level", game.level_number == 2 and game.hud.level_text() == "LEVEL 2/50", game.hud.level_text())
	await _tap("stream_level_up")
	_check("F2b", "a second F2 advances one more level", game.level_number == 3)
	await _tap("stream_level_down")
	_check("F3", "F3 goes back one level", game.level_number == 2)
	await _tap("stream_level_down5")
	_check("F5", "F5 cannot go below level 1", game.level_number == 1)
	await _tap("stream_level_up5")
	_check("F4", "F4 advances five levels", game.level_number == 6, game.hud.level_text())
	var monsters: int = game.level.enemies.size()
	await _tap("stream_add_monster")
	_check("F6", "F6 adds one monster", game.level.enemies.size() == monsters + 1, "%d" % game.level.enemies.size())
	await _tap("stream_reset_arm")
	var left: float = game._countdown
	await _seconds(0.3)
	await _tap("stream_reset_arm")
	_check("F7", "F7 starts one 60 second reset", left <= 60.0 and left > 59.0 and game._countdown < left and game._countdown > 50.0,
		"%.2f then %.2f" % [left, game._countdown])
	await _tap("stream_reset_save")
	_check("F9", "F9 cancels the reset", game._countdown < 0.0 and game.level_number == 6 and game.hud._saved.visible)
	game.deaths = 4
	game.completed_levels.append(1)
	await _tap("stream_reset_now")
	_check("F8", "F8 resets the run to level 1", game.level_number == 1 and game.deaths == 0 and game.completed_levels.is_empty() and game.hud.level_text() == "LEVEL 1/50")
	game.go_to_level(50)
	await _frames(5)
	await _tap("stream_level_up")
	var stayed: bool = game.level_number == 50
	await _tap("stream_level_up5")
	_check("cap", "level shortcuts stay inside 1 to 50", stayed and game.level_number == 50)


func _test_all_levels() -> void:
	game.hold_level = true
	game.finish_fade = 0.02
	GrassScript.dense = false
	game._load_level(1)
	await _frames(5)
	var bad := ""
	for number in 50:
		var n := number + 1
		if game.level_number != n:
			bad = "arrived on %d, expected %d" % [game.level_number, n]
			break
		var platforms: Array = game.level.platforms
		var spider := false
		for enemy in game.level.enemies:
			if enemy.kind == "spider":
				spider = true
		if n >= 25 and not spider:
			bad = "level %d has no spider" % n
			break
		if n < 25 and spider:
			bad = "level %d has a spider too early" % n
			break
		var done: int = _completions
		var failed_at := ""
		for enemy in game.level.enemies:
			enemy.frozen = true
		player.teleport(game.level.start_position(), game.level.start_yaw())
		await _until(player.is_on_floor, 1.0)
		for i in range(platforms.size() - 1):
			var ok: bool = await _hop(platforms[i], platforms[i + 1], i + 1 == platforms.size() - 1)
			if not ok:
				failed_at = "level %d jump %d floor %s vel %s player %s" % [n, i + 1, player.is_on_floor(), player.velocity, player.global_position]
				break
		if failed_at != "":
			bad = failed_at
			break
		var finished := _completions > done
		if not finished:
			finished = await _until(func() -> bool: return _completions > done, 2.0)
		if not finished:
			bad = "level %d finish pad" % n
			break
		var settled: bool = await _until(func() -> bool: return game.phase == game.Phase.PLAYING, 3.0)
		if not settled:
			bad = "level %d stayed in the finish fade" % n
			break
		if n < 50:
			game.go_to_level(n + 1)
			await _frames(5)
	_check("levels", "all 50 routes can be finished", bad == "", bad if bad != "" else "50 routes")


# ---------------------------------------------------------------- the jumping bot

# Walk to the edge of `from`, jump, land on `to`, walk to its middle. Sprints only when the gap needs it.
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)


func _hop(from: StaticBody3D, to: StaticBody3D, is_last: bool) -> bool:
	var from_rect: Rect2 = from.rect()
	var to_rect: Rect2 = to.rect()
	var target := to_rect.get_center()
	if _rect_gap(from_rect, to_rect) > 1.7 or absf(to.top - from.top) > 0.35:
		Input.action_press("sprint")
	var jumped := false
	var landed := false
	var completions_before := _completions
	for i in 60 * 8:
		from_rect = from.rect()
		to_rect = to.rect()
		target = to_rect.get_center()
		if is_last and _completions > completions_before:
			_release_all()
			return true
		var at := _flat(player.global_position)
		var direction := (target - at).normalized()
		player.set_look(atan2(-direction.x, -direction.y), 0.0)
		if not jumped:
			Input.action_press("move_forward")
			if not from_rect.has_point(at + direction * 0.38):
				Input.action_press("jump")
				jumped = true
		else:
			Input.action_release("jump")
			# Ease off over the landing spot so the bot does not overshoot.
			if to_rect.grow(-0.25).has_point(at) or at.distance_to(target) < 0.45:
				Input.action_release("move_forward")
			else:
				Input.action_press("move_forward")
			if game.level.hazard.player_inside:
				break
			if player.is_on_floor() and to_rect.has_point(at) and absf(player.global_position.y - to.top) < 0.12:
				landed = true
				break
		await get_tree().physics_frame
	_release_all()
	if not landed:
		return false
	# Walk to the middle. On the last platform that is where the finish pad is.
	for i in 60 * 3:
		var at := _flat(player.global_position)
		if is_last and _completions > completions_before:
			break
		if at.distance_to(target) < 0.25:
			break
		var direction := (target - at).normalized()
		player.set_look(atan2(-direction.x, -direction.y), 0.0)
		Input.action_press("move_forward")
		await get_tree().physics_frame
	_release_all()
	await _seconds(0.2)
	return is_last or (player.is_on_floor() and to.rect().has_point(_flat(player.global_position)))


# ---------------------------------------------------------------- screenshots

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var platforms: Array = game.level.platforms
	player.lock()
	ant.frozen = true
	ant.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)), Vector3(-13.6, 0.0, -2.6))
	# The noise textures are generated on background threads. Give them time.
	for i in 150:
		await get_tree().process_frame
	var views := [
		["01_start", platforms[0].top_center(), game.level.start_yaw(), -0.12],
		["02_ant_face", Vector3(-10.86, 0.0, -3.5), atan2(1.8, -0.56), -0.536],
		["03_ant", Vector3(-15.4, 0.0, -1.6), atan2(-1.8, 1.0), -0.42],
		["04_platform_3", platforms[3].top_center(), -PI * 0.5, -0.2],
		["05_beam", platforms[mini(4, platforms.size() - 1)].top_center(), 0.0, -0.25],
		["06_before_finish", platforms[mini(5, platforms.size() - 2)].top_center(), atan2(-3.8, -4.0), -0.15],
		["07_from_the_grass", Vector3(-9.0, 0.0, 4.5), atan2(-2.8, 3.1), 0.05],
		["08_ceiling", platforms[mini(3, platforms.size() - 1)].top_center(), 0.6, 0.75],
		["09_dark_corner", platforms[mini(6, platforms.size() - 1)].top_center(), atan2(-12.0, 4.0), -0.1],
	]
	for view: Array in views:
		player.global_position = view[1]
		player.set_look(view[2], view[3])
		await _snap(dir, view[0])
	game.set_look("outdoor")
	for i in 30:
		await get_tree().process_frame
	_bind_ant()
	player.lock()
	ant.frozen = true
	var start: Vector3 = game.level.start_position()
	player.global_position = start
	player.set_look(game.level.start_yaw(), -0.18)
	await _snap(dir, "13_outdoor")
	player.set_look(game.level.start_yaw(), 0.35)
	await _snap(dir, "14_outdoor_sky")
	game.set_look("dungeon")
	for i in 8:
		await get_tree().process_frame
	_bind_ant()
	platforms = game.level.platforms

	# Jumpscare, three moments.
	ant.frozen = false
	player.unlock()
	player.teleport(Vector3(-12.0, 0.02, -1.0), 0.0)
	ant.global_transform = Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.0, 1.2))
	for i in 240:
		if game.phase == game.Phase.DYING:
			break
		await get_tree().physics_frame
	for moment: Array in [["10_jumpscare_lunge", 0.30], ["11_jumpscare_bite", 0.12], ["12_jumpscare_bite", 0.12]]:
		await get_tree().create_timer(moment[1]).timeout
		await _snap(dir, moment[0])

	# Frame rate from the start platform with the frame cap off. Only meaningful on the machine that ran it.
	await get_tree().create_timer(2.5).timeout
	player.lock()
	ant.frozen = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	player.global_position = platforms[0].top_center()
	player.set_look(game.level.start_yaw(), -0.12)
	for i in 90:
		await get_tree().process_frame
	var began := Time.get_ticks_usec()
	for i in 240:
		await get_tree().process_frame
	var window := get_window().size
	print("frame rate: %.0f fps, window %dx%d, 3D drawn at %d lines, %s" % [240.0 / ((Time.get_ticks_usec() - began) / 1000000.0),
		window.x, window.y, roundi(window.y * get_viewport().scaling_3d_scale), RenderingServer.get_video_adapter_name()])


func _snap(dir: String, shot: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [dir, shot])
	print("saved %s/%s.png" % [dir, shot])


# ---------------------------------------------------------------- helpers

func _check(number: String, what: String, passed: bool, detail := "") -> void:
	if not passed:
		_failed += 1
	var line := "%s  %-4s %s" % ["PASS" if passed else "FAIL", number, what]
	print(line if detail == "" else "%s  [%s]" % [line, detail])


func _on_line_started(event: String, _id: String, _backend: String) -> void:
	if _narrator_busy:
		_narrator_overlap = true
	_narrator_busy = true
	_spoken.append(event)


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


func _grass_south_of(platform: StaticBody3D) -> Vector2:
	var r: Rect2 = platform.rect()
	return Vector2(r.get_center().x, r.end.y + 0.85)


func _on_start_pad_rear() -> void:
	var yaw: float = game.level.start_yaw()
	player.teleport(game.level.start_position(), yaw)
	await _frames(2)
	var back := player.global_transform.basis.z
	back.y = 0.0
	if back.length() > 0.01:
		back = back.normalized()
		player.teleport(game.level.start_position() + Vector3(back.x, 0.0, back.z) * 1.45, yaw)
	await _frames(2)


func _release_all() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)


func _put_on_platform(platform: StaticBody3D) -> void:
	player.teleport(platform.top_center() + Vector3(0.0, 0.02, 0.0), player.yaw)
	await _frames(2)
	await _until(player.is_on_floor, 1.0)


func _put_on_grass(at: Vector2) -> void:
	player.teleport(Vector3(at.x, 0.02, at.y), player.yaw)
	await _until(func() -> bool: return game.level.hazard.player_inside, 1.0)
	await _frames(2)


func _bind_ant() -> void:
	ant = game.level.enemies[0]
	if not ant.state_changed.is_connected(_on_ant_state):
		ant.state_changed.connect(_on_ant_state)


func _on_ant_state(_enemy: CharacterBody3D, state: int) -> void:
	_states.append(state)


func _place_ant(at: Vector2) -> void:
	ant.frozen = false
	ant.velocity = Vector3.ZERO
	var wanted := Vector3(at.x, 0.0, at.y)
	var map: RID = ant.nav.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) != 0:
		wanted = NavigationServer3D.map_get_closest_point(map, wanted)
	ant.global_position = Vector3(wanted.x, 0.0, wanted.z)
	ant._repath = 0.0


func _ant_gap() -> float:
	return _flat(ant.global_position).distance_to(_flat(player.global_position))


func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


func _flat_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
