extends Node
## The numbers of one run: balls left in each level, what the vacuum holds, what the pit holds, the clock.
##
## The ball manager owns where the balls are. This owns how many there are. Every ball is in exactly one place:
##   left in a level + in the vacuum + in the pit = balls in the run
## `balls_in_run()` starts at 250,000 and only changes when viewers add or remove balls (a later phase).

signal counts_changed
signal level_unlocked(level: int)
signal sweep_started
signal vacuum_filled
signal run_reset

const VACUUM_CAPACITY := 50000
## A level opens the next door when this many balls or fewer are still on the floor.
const CLEAR_LEFT := 10

## The seven levels in play order. `balls` is the starting count and adds up to 250,000.
const LEVELS := [
	{"name": "Playroom", "balls": 20000},
	{"name": "Poolroom", "balls": 35000},
	{"name": "Craft Closet", "balls": 35000},
	{"name": "Wet Room", "balls": 35000},
	{"name": "Costume Store", "balls": 40000},
	{"name": "Staff Hall", "balls": 40000},
	{"name": "Boiler", "balls": 45000},
]

var remaining := PackedInt32Array()
var unlocked: Array[bool] = []
var current_level := 0
var vacuum_stored := 0
var deposited := 0
var run_time := 0.0
var sweeping := false


func _ready() -> void:
	reset_run()


func _process(delta: float) -> void:
	run_time += delta


func reset_run() -> void:
	remaining.resize(LEVELS.size())
	unlocked.resize(LEVELS.size())
	for i in LEVELS.size():
		remaining[i] = LEVELS[i]["balls"]
		unlocked[i] = i == 0
	current_level = 0
	vacuum_stored = 0
	deposited = 0
	run_time = 0.0
	sweeping = false
	run_reset.emit()
	counts_changed.emit()


func set_current_level(level: int) -> void:
	level = clampi(level, 0, LEVELS.size() - 1)
	if current_level == level:
		return
	current_level = level
	counts_changed.emit()


func level_name(level: int) -> String:
	return LEVELS[level]["name"]


func starting_balls(level: int) -> int:
	return LEVELS[level]["balls"]


func total_remaining() -> int:
	var total := 0
	for count in remaining:
		total += count
	return total


func balls_in_run() -> int:
	return total_remaining() + vacuum_stored + deposited


func vacuum_space() -> int:
	return VACUUM_CAPACITY - vacuum_stored


func vacuum_full() -> bool:
	return vacuum_stored >= VACUUM_CAPACITY


## The ball manager reports how many balls its level still holds.
## CLEAR_LEFT or fewer still on the floor is enough to open the next door.
func set_level_remaining(level: int, count: int) -> void:
	count = maxi(count, 0)
	if remaining[level] == count:
		return
	remaining[level] = count
	if count <= CLEAR_LEFT:
		if level + 1 < LEVELS.size() and not unlocked[level + 1]:
			unlocked[level + 1] = true
			level_unlocked.emit(level + 1)
		if level == LEVELS.size() - 1 and not sweeping:
			sweeping = true
			sweep_started.emit()
	counts_changed.emit()


## Balls that just left a level and entered the vacuum. The caller must not pass more than `vacuum_space()`.
func store_in_vacuum(count: int) -> void:
	if count <= 0:
		return
	var was_full := vacuum_full()
	vacuum_stored = mini(vacuum_stored + count, VACUUM_CAPACITY)
	if vacuum_full() and not was_full:
		vacuum_filled.emit()
	counts_changed.emit()


## Moves up to `count` balls from the vacuum into the pit. Returns how many moved.
func deposit(count: int) -> int:
	var moved := clampi(count, 0, vacuum_stored)
	if moved == 0:
		return 0
	vacuum_stored -= moved
	deposited += moved
	counts_changed.emit()
	return moved
