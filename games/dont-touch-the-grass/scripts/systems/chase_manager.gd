# The chase rules, in one place, with one timer for every monster.
#
#   A. Player touches grass        nearby monsters start CHASING.
#   B. Player lands on a platform  chasing monsters switch to SEARCHING (follow from below, cannot attack)
#                                  and the 5 second timer starts.
#   C. Timer runs out              monsters go back to ROAMING.
#   D. Player touches grass again  timer is cancelled, monsters are CHASING again.
#                                  The next 5 seconds only start on the next landing.
#
# Jumping from platform to platform does not touch the grass, so it does not reset the timer.
extends Node

signal chase_started
signal reached_safety
signal chase_ended

const EnemyScript = preload("res://scripts/enemies/enemy.gd")

const SAFE_SECONDS := 5.0

var player: CharacterBody3D
var hazard: Area3D
var chase_active := false
# True from touching the grass until the next landing on a platform. Monsters can only kill while this is true.
var player_in_danger := false
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SAFE_SECONDS
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer.timeout.connect(_end_chase)
	add_child(_timer)


func bind(p_player: CharacterBody3D, p_hazard: Area3D) -> void:
	player = p_player
	hazard = p_hazard
	hazard.player_touched_grass.connect(_on_grass_touched)


# Forget the chase. Used after a death and when a level starts. Monsters are reset by the caller.
func reset() -> void:
	_timer.stop()
	player_in_danger = false
	if chase_active:
		chase_active = false
		chase_ended.emit()


# Seconds left on the safe-platform countdown. 0 when it is not running.
func time_left() -> float:
	return _timer.time_left


func _on_grass_touched() -> void:
	player_in_danger = true
	_timer.stop()
	for enemy in _enemies():
		if enemy.state == EnemyScript.State.SEARCHING:
			enemy.set_state(EnemyScript.State.CHASING)
	if not chase_active:
		chase_active = true
		chase_started.emit()


func _physics_process(_delta: float) -> void:
	if not player_in_danger or player == null:
		return
	# Monsters that wander close while the player is still on the grass notice too.
	for enemy in _enemies():
		if enemy.state == EnemyScript.State.ROAMING and enemy.can_detect(player.global_position):
			enemy.set_state(EnemyScript.State.CHASING)
	# Standing on something that is not grass means standing on a platform.
	if player.is_on_floor() and not hazard.player_inside:
		player_in_danger = false
		var followers := 0
		for enemy in _enemies():
			if enemy.state == EnemyScript.State.CHASING:
				enemy.set_state(EnemyScript.State.SEARCHING)
				followers += 1
		if followers > 0:
			_timer.start(SAFE_SECONDS)
			reached_safety.emit()
		else:
			_end_chase()


func _end_chase() -> void:
	_timer.stop()
	for enemy in _enemies():
		enemy.set_state(EnemyScript.State.ROAMING)
	chase_active = false
	chase_ended.emit()


func _enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group("enemies")
