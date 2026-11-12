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
		{"id": "intro_1", "text": "Don't touch the grass."},
	]},
	"grass": {"priority": 2, "cooldown": 18.0, "queue": false, "lines": [
		{"id": "grass_1", "text": "Oops. I think you made a mistake."},
		{"id": "grass_2", "text": "That was the grass. The one thing I asked you not to touch."},
		{"id": "grass_3", "text": "Oops. Off the platform."},
	]},
	"death": {"priority": 3, "cooldown": 0.0, "queue": false, "lines": [
		{"id": "death_1", "text": "Oops. I think you made a mistake."},
		{"id": "death_2", "text": "And you are dead. I did warn you."},
		{"id": "death_3", "text": "The ant says thank you."},
	]},
	"death_many": {"priority": 3, "cooldown": 0.0, "queue": false, "lines": [
		{"id": "death_many_1", "text": "Oops. Again."},
		{"id": "death_many_2", "text": "At this point the ants know you by name."},
	]},
}
