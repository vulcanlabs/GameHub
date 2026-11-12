extends Node3D
## Starts the game: puts the balls in Level 1 and Level 2, hands each part what it needs, and owns pause and restart.
##
## Developer switches, after `--` on the command line (see scripts/dev/playtest.gd):
##   --playtest          run the automatic test and quit
##   --shots=<folder>    save screenshots and a frame-time reading, then quit
##   --perf              measure what each graphics feature costs, then quit

const Playtest := preload("res://scripts/dev/playtest.gd")

@onready var level: Level1Hub = $Level
@onready var level2: Level2Pool = $Level2
@onready var balls: BallManager = $Balls
@onready var balls2: BallManager = $Balls2
@onready var flyers: BallFlyers = $Flyers
@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	balls.setup(level.LEVEL_INDEX, level.ball_bounds(), 0.0, level.blocked_areas())
	balls.viewer = player.camera
	balls.populate(GameState.starting_balls(level.LEVEL_INDEX), level.PILES, level.BALL_SEED)

	balls2.setup(level2.LEVEL_INDEX, level2.ball_bounds(), 0.0, level2.blocked_areas())
	balls2.viewer = player.camera
	balls2.populate(GameState.starting_balls(level2.LEVEL_INDEX), level2.PILES, level2.BALL_SEED)

	player.vacuum.balls = balls
	player.vacuum.rooms = [balls, balls2]
	player.vacuum.flyers = flyers
	flyers.suction_point = player.vacuum.suction_point
	for pit in level.pits:
		pit.flyers = flyers
	hud.pits = level.pits
	player.teleport(level.spawn_point(), level.spawn_yaw())

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
	var in_pool := player.global_position.x > level.WIDTH * 0.5 + 0.2
	GameState.set_current_level(1 if in_pool else 0)


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
	GameState.reset_run()
	balls.populate(GameState.starting_balls(level.LEVEL_INDEX), level.PILES, level.BALL_SEED)
	balls2.populate(GameState.starting_balls(level2.LEVEL_INDEX), level2.PILES, level2.BALL_SEED)
	flyers.clear()
	player.teleport(level.spawn_point(), level.spawn_yaw())
	set_paused(false)


func _on_level_unlocked(level: int) -> void:
	if level == 1:
		player.teleport(level2.spawn_point(), level2.spawn_yaw())


func _on_sweep() -> void:
	player.teleport(level.spawn_point(), level.spawn_yaw())


func _exit_game() -> void:
	Settings.save()
	get_tree().quit()
