# Everything the narrator can say. Edit the text here; add more lines to any list.
#
# Recording a line: save it as res://audio/narrator/<id>.ogg (or .wav / .mp3), for example
# res://audio/narrator/intro_1.ogg. The narrator plays the file as soon as it exists.
#
#   priority  a higher number cuts off a lower one that is still talking.
#   cooldown  seconds before the same event may be commented on again.
#   queue     true: wait for the narrator to finish and then speak. false: stay silent if he is busy.
extends RefCounted

const EVENTS := {
	"intro": {"priority": 1, "cooldown": 0.0, "queue": true, "lines": [
		{"id": "intro_1", "text": "Welcome to Don't Touch the Grass. There is literally one rule. Don't touch the grass. Think you can handle that?"},
	]},
	"tutorial_move": {"priority": 1, "cooldown": 0.0, "queue": true, "lines": [
		{"id": "tutorial_move_1", "text": "Walk with W, A, S and D. Hold Shift to sprint. Press Space to jump. Yes, I really do have to explain this."},
	]},
	"tutorial_jump": {"priority": 1, "cooldown": 0.0, "queue": true, "lines": [
		{"id": "tutorial_jump_1", "text": "See that platform? Jump onto it. Preferably without embarrassing yourself."},
	]},
	"grass": {"priority": 2, "cooldown": 25.0, "queue": false, "lines": [
		{"id": "grass_1", "text": "Oh, brilliant. You've attracted the ants."},
		{"id": "grass_2", "text": "One rule. There was one rule."},
		{"id": "grass_3", "text": "The grass. Of course you touched the grass."},
	]},
	"death": {"priority": 3, "cooldown": 0.0, "queue": false, "lines": [
		{"id": "death_1", "text": "That was impressive. I've never seen someone fail quite so confidently."},
		{"id": "death_2", "text": "And you are dead. I am shocked. Truly."},
		{"id": "death_3", "text": "The ant says thank you."},
	]},
	"death_many": {"priority": 3, "cooldown": 0.0, "queue": false, "lines": [
		{"id": "death_many_1", "text": "Are you trying to complete the game, or are you feeding the ants?"},
		{"id": "death_many_2", "text": "At this point the ants know you by name."},
	]},
	"level_complete": {"priority": 3, "cooldown": 0.0, "queue": false, "lines": [
		{"id": "level_complete_1", "text": "Congratulations. You survived. Somehow."},
		{"id": "level_complete_2", "text": "You made it. Do not let it go to your head."},
	]},
}
