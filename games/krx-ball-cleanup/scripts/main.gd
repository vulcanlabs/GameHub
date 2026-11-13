extends Node3D
## Starts the game: puts the balls in Level 1 and Level 2, hands each part what it needs, and owns pause and restart.
##
## Developer switches, after `--` on the command line (see scripts/dev/playtest.gd):
##   --playtest          run the automatic test and quit
##   --shots=<folder>    save screenshots and a frame-time reading, then quit
##   --perf              measure what each graphics feature costs, then quit

const Playtest := preload("res://scripts/dev/playtest.gd")

@onready var level: Level1Hub = $Level
@onready var balls: BallManager = $Balls
@onready var flyers: BallFlyers = $Flyers
@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu

## Rooms after the playroom, in play order: pool, backrooms, waiting room, office, ball pit.
var maps: Array = []
var rooms: Array[BallManager] = []

## Bumped on restart so a pending "level completed" teleport does not fire into the new run.
var _move_token := 0
## Bumped so a restart does not keep filling the rooms from the previous run.
var _fill_token := 0


func _ready() -> void:
	_build_maps()
	balls.setup(level.LEVEL_INDEX, level.ball_bounds(), 0.0, level.blocked_areas(), level.blocked_circles())
	balls.viewer = player.camera
	balls.populate(GameState.starting_balls(level.LEVEL_INDEX), level.PILES, level.BALL_SEED)
	rooms = [balls]
	for i in maps.size():
		var map = maps[i]
		var pile := BallManager.new()
		pile.name = "Balls%d" % (int(map.level_index) + 1)
		add_child(pile)
		pile.setup(int(map.level_index), map.ball_bounds(), 0.0, map.blocked_areas())
		pile.viewer = player.camera
		rooms.append(pile)
	_queue_room_balls()

	player.vacuum.balls = balls
	player.vacuum.rooms = rooms
	player.vacuum.flyers = flyers
	flyers.suction_point = player.vacuum.suction_point
	for pit in level.pits:
		pit.flyers = flyers
	hud.pits = level.pits
	player.teleport(level.spawn_point(), level.spawn_yaw())
	player.remember_checkpoint(level.spawn_point(), level.spawn_yaw())

	pause_menu.resume_pressed.connect(set_paused.bind(false))
	pause_menu.restart_pressed.connect(restart_run)
	pause_menu.exit_pressed.connect(_exit_game)
	GameState.level_unlocked.connect(_on_level_unlocked)
	GameState.sweep_started.connect(_on_sweep)

	for arg in OS.get_cmdline_user_args():
		if arg == "--playtest" or arg.begins_with("--shots=") or arg == "--perf":
			var tool := Playtest.new()
			add_child(tool)
			if arg == "--perf":
				tool.perf(self)
			else:
				tool.run(self, arg.trim_prefix("--shots=") if arg.begins_with("--shots=") else "")
			return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	hud.show_click_hint(player.require_mouse_capture and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	var here := 0
	for i in maps.size():
		var map = maps[i]
		if map.contains(player.global_position):
			here = int(map.level_index)
			break
	GameState.set_current_level(here)
	if player.global_position.y < -1.2:
		player.respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		pause_menu.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		pause_menu.close()
		if player.require_mouse_capture:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart_run() -> void:
	_move_token += 1
	GameState.reset_run()
	balls.populate(GameState.starting_balls(level.LEVEL_INDEX), level.PILES, level.BALL_SEED)
	_queue_room_balls()
	flyers.clear()
	player.teleport(level.spawn_point(), level.spawn_yaw())
	player.remember_checkpoint(level.spawn_point(), level.spawn_yaw())
	set_paused(false)


func _on_level_unlocked(next_level: int) -> void:
	if next_level < 1 or next_level > maps.size():
		return
	_move_token += 1
	_enter_next_level(next_level, _move_token)


## The HUD says the level is done first. The move happens once that line has been up.
func _enter_next_level(next_level: int, token: int) -> void:
	await get_tree().create_timer(2.4).timeout
	if token != _move_token or not is_instance_valid(player):
		return
	var map = maps[next_level - 1]
	player.teleport(map.spawn_point(), map.spawn_yaw())
	player.remember_checkpoint(map.spawn_point(), map.spawn_yaw())


## One room per frame. Filling every hill before the first frame kept the window from opening.
func _queue_room_balls() -> void:
	_fill_token += 1
	_fill_rooms(_fill_token, 0)


func _fill_rooms(token: int, index: int) -> void:
	if token != _fill_token or index >= maps.size():
		return
	var map = maps[index]
	var level_index := int(map.level_index)
	rooms[level_index].populate(GameState.starting_balls(level_index), map.PILES, int(map.ball_seed))
	call_deferred("_fill_rooms", token, index + 1)


func _build_maps() -> void:
	# Only the playroom is in the world for now. The HUD still lists all seven levels.
	pass


func _on_sweep() -> void:
	player.teleport(level.spawn_point(), level.spawn_yaw())
	player.remember_checkpoint(level.spawn_point(), level.spawn_yaw())


func _exit_game() -> void:
	Settings.save()
	get_tree().quit()
