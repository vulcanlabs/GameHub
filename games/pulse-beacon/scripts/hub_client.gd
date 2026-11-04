extends Node

signal linked
signal link_failed(message: String)
signal actions_received(events: Array)
signal session_ended(message: String)
signal poll_note(message: String)

const SLUG := "pulse-beacon"
const CFG_PATH := "user://pulse_beacon.cfg"

var base_url := "http://localhost:3000"
var token := ""
var _mode := "idle"
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 40.0
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	_load()


func has_token() -> bool:
	return token != ""


func clear_link() -> void:
	_mode = "idle"
	token = ""
	_save()


func start_link(hub: String, code: String, device_name: String) -> void:
	base_url = hub.strip_edges()
	var body := {
		"code": code.strip_edges(),
		"slug": SLUG,
		"deviceName": device_name.strip_edges(),
	}
	_mode = "link"
	var err := _http.request(
		_root() + "/api/v1/devices/link",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		_mode = "idle"
		link_failed.emit("Could not reach the hub")


func start_poll() -> void:
	if token == "":
		return
	_mode = "poll"
	_poll_once()


func post_state(status: String) -> void:
	if token == "":
		return
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, _body): http.queue_free())
	http.request(
		_root() + "/api/v1/devices/state",
		PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer " + token,
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"slug": SLUG, "status": status})
	)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	base_url = str(cfg.get_value("hub", "base_url", base_url))
	token = str(cfg.get_value("hub", "token", ""))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hub", "base_url", base_url)
	cfg.set_value("hub", "token", token)
	cfg.set_value("hub", "slug", SLUG)
	cfg.save(CFG_PATH)


func _root() -> String:
	var url := base_url.strip_edges()
	while url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	return url


func _poll_once() -> void:
	if _mode != "poll" or token == "":
		return
	var err := _http.request(
		_root() + "/api/v1/devices/live?slug=" + SLUG.uri_encode(),
		PackedStringArray(["Authorization: Bearer " + token]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		poll_note.emit("Poll did not start. Retrying.")
		await get_tree().create_timer(1.0).timeout
		_poll_once()


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if _mode == "link":
		_mode = "idle"
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or typeof(parsed) != TYPE_DICTIONARY:
			var msg := "Link failed"
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("message"):
				msg = str(parsed["message"])
			link_failed.emit(msg)
			return
		token = str(parsed.get("token", ""))
		if token == "":
			link_failed.emit("Hub did not return a token")
			return
		_save()
		linked.emit()
		return
	if _mode != "poll":
		return
	if code == 401 or code == 403:
		var ended := "Access ended"
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("message"):
			ended = str(parsed["message"])
		clear_link()
		session_ended.emit(ended)
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		poll_note.emit("Hub unreachable. Retrying.")
		await get_tree().create_timer(1.0).timeout
		_poll_once()
		return
	if code == 200 and typeof(parsed) == TYPE_DICTIONARY:
		var events: Variant = parsed.get("events", [])
		if typeof(events) == TYPE_ARRAY and events.size() > 0:
			actions_received.emit(events)
	_poll_once()
