class_name RunClient
extends Node
## Talks to the Study Arena server's authoritative dungeon run API.
## With no run ticket the game plays an offline practice run (coins are not saved).

var api_base := ""
var run_id := ""
var ticket := ""

func configure(base: String, run: String, run_ticket: String) -> void:
	api_base = base.strip_edges().trim_suffix("/")
	run_id = run.strip_edges()
	ticket = run_ticket.strip_edges()

func is_linked() -> bool:
	return not api_base.is_empty() and _valid_id(run_id) and ticket.length() >= 20

func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 80:
		return false
	for c in value:
		if not (c.is_valid_identifier() or c.is_valid_int() or c == "-"):
			return false
	return true

func fetch_questions() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/dungeon/runs/%s/questions" % run_id, {})

func answer(index: int, choice: int) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/dungeon/runs/%s/answer" % run_id, {"index": index, "choice": choice})

func hint(index: int) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/dungeon/runs/%s/hint" % run_id, {"index": index})

func finish(outcome: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/dungeon/runs/%s/finish" % run_id, {"outcome": outcome})

## Returns {"ok": bool, "status": int, "data": Dictionary, "error": String}.
func _request(method: int, path: String, body: Dictionary, attempts := 3) -> Dictionary:
	var last := {"ok": false, "status": 0, "data": {}, "error": "NETWORK"}
	for attempt in attempts:
		var http := HTTPRequest.new()
		http.timeout = 12.0
		add_child(http)
		var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json", "X-Dungeon-Ticket: " + ticket])
		var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
		var err := http.request(api_base + path, headers, method, payload)
		if err != OK:
			http.queue_free()
			last.error = "REQUEST_FAILED"
			continue
		var result: Array = await http.request_completed
		http.queue_free()
		var status: int = result[1]
		var text := (result[3] as PackedByteArray).get_string_from_utf8()
		var parsed = JSON.parse_string(text) if not text.is_empty() else {}
		var data: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		if result[0] == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300:
			return {"ok": true, "status": status, "data": data, "error": ""}
		var code := "HTTP_%d" % status if status > 0 else "NETWORK"
		var error_value = data.get("error", null)
		if typeof(error_value) == TYPE_DICTIONARY:
			code = String(error_value.get("code", code))
		elif error_value != null:
			code = String(error_value)
		last = {"ok": false, "status": status, "data": data, "error": code}
		if status >= 400 and status < 500:
			return last # client errors are not retried (ticket, closed run, coins)
		await get_tree().create_timer(0.6 * float(attempt + 1)).timeout
	return last
