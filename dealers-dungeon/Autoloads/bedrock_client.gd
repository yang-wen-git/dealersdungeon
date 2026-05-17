extends Node

## BedrockClient — Autoload singleton for AI dialog via a Lambda proxy.
##
## The game no longer holds AWS credentials. All Bedrock authentication happens
## on the Lambda side using its IAM execution role. The game only needs:
##   • endpoint — the API Gateway invoke URL
##   • api_key  — the API Gateway API key (basic abuse prevention)
##
## The public API (invoke / generate / signals) is identical to the previous
## SigV4 version, so no call sites need changing:
##
##   # 1. Simple — listen on the global signals:
##   BedrockClient.response_received.connect(_on_text)
##   BedrockClient.request_failed.connect(_on_error)
##   BedrockClient.invoke("Greet the player as a shady merchant.")
##
##   # 2. Recommended — per-request callback + a persona:
##   BedrockClient.generate(
##       "The player offers 3 gold for a rusty sword.",
##       func(text): dialog_box.show_text(text),
##       {
##           "system": "You are Grix, a greedy dungeon merchant. One sentence.",
##           "max_tokens": 256,
##           "on_error": func(err): dialog_box.show_text("...")
##       })
##
## Concurrent calls are safe: requests are queued because the underlying
## HTTPRequest node serves one request at a time.


# ── Config ────────────────────────────────────────────────────────────────────
# Loaded at runtime from aws_config.cfg (gitignored). See aws_config.cfg.example
# for the file format. No AWS credentials live here — the proxy authenticates
# server-side with its IAM execution role.
# WARNING: Files under res:// are bundled into exported Godot builds by default.
# Do not ship aws_config.cfg inside an export. Before release, either exclude
# this file from export filters or move secrets to user://, environment
# variables, or a backend/token-vending flow.

const _CONFIG_PATH := "res://aws_config.cfg"

var _endpoint := ""
var _api_key  := ""


# ── Signals ───────────────────────────────────────────────────────────────────
## Emitted when a request made via invoke() (no callback) succeeds.
signal response_received(text: String)

## Emitted when a request with no on_error callback fails. Carries a description.
signal request_failed(error: String)


# ── Internals ─────────────────────────────────────────────────────────────────
var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _busy := false


func _ready() -> void:
	_load_config()
	_ensure_http()


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	add_child(_http)
	# Without a timeout (default 0 = infinite) a hung request leaves _busy = true
	# forever and every queued generate() call stalls. 35s sits just above the
	# Lambda's 30s timeout so its structured 502 wins the race over a blind
	# client-side timeout.
	_http.timeout = 35.0
	_http.request_completed.connect(_on_request_completed)


func _load_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(_CONFIG_PATH)
	if err != OK:
		push_error("BedrockClient: could not load %s (error %d). Copy aws_config.cfg.example to aws_config.cfg and fill it in." % [_CONFIG_PATH, err])
		return
	_endpoint = config.get_value("proxy", "endpoint", "")
	_api_key  = config.get_value("proxy", "api_key", "")
	if _endpoint.is_empty():
		push_error("BedrockClient: aws_config.cfg is missing [proxy] endpoint.")


# ── Public API ────────────────────────────────────────────────────────────────

## Backward-compatible simple call. Results arrive on the global
## response_received / request_failed signals.
func invoke(prompt: String) -> void:
	generate(prompt)


## Preferred entry point.
##
## prompt   the user message to send.
## on_done  optional Callable(text: String) invoked on success. If omitted, the
##          response_received signal is emitted instead.
## opts     optional Dictionary, all keys optional:
##            "system"      String   persona / instructions for the model
##            "max_tokens"  int      response length cap (default 512)
##            "temperature" float    sampling temperature (model default if unset)
##            "on_error"    Callable Callable(error: String) on failure. If
##                                   omitted, the request_failed signal is used.
func generate(prompt: String, on_done := Callable(), opts: Dictionary = {}) -> void:
	_queue.push_back({
		"prompt": prompt,
		"on_done": on_done,
		"on_error": opts.get("on_error", Callable()),
		"system": String(opts.get("system", "")),
		"max_tokens": int(opts.get("max_tokens", 512)),
		"temperature": opts.get("temperature", null),
	})
	_pump()


# ── Request queue ─────────────────────────────────────────────────────────────

func _pump() -> void:
	if _busy or _queue.is_empty():
		return

	if _endpoint.is_empty():
		var bad: Dictionary = _queue.pop_front()
		_dispatch_error(bad, "Proxy endpoint not configured (see aws_config.cfg).")
		_pump()
		return

	_busy = true
	_current = _queue.pop_front()
	_send(_current)


func _send(req: Dictionary) -> void:
	_ensure_http()

	var payload := {
		"prompt": req["prompt"],
		"max_tokens": req["max_tokens"],
	}
	if not String(req["system"]).is_empty():
		payload["system"] = req["system"]
	if req["temperature"] != null:
		payload["temperature"] = float(req["temperature"])

	var body := JSON.stringify(payload)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: " + _api_key,
	])

	var err := _http.request(_endpoint, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_finish_error("HTTPRequest node error code: %d" % err)


# ── Response handling ─────────────────────────────────────────────────────────

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw := body.get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish_error("HTTP %d — %s" % [response_code, _truncate(raw)])
		return

	var json := JSON.new()
	if json.parse(raw) != OK:
		_finish_error("Could not parse JSON response: " + _truncate(raw))
		return

	# Defensive: a well-formed-but-unexpected payload (non-object top level)
	# must route through _finish_error. A bare `var data: Dictionary = ...`
	# assignment here would raise a runtime error that bypasses _finish_error
	# and leaves _busy = true, wedging the queue for every subsequent request.
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish_error("Unexpected response shape: " + _truncate(raw))
		return

	var data: Dictionary = parsed
	var text_value: Variant = data.get("text", "")
	if typeof(text_value) != TYPE_STRING or String(text_value).is_empty():
		_finish_error("Unexpected response shape: " + _truncate(raw))
		return

	_finish_success(String(text_value))


## Caps an arbitrary response body before it is surfaced to on_error / signals.
## API-Gateway and Bedrock error bodies can be large and echo request details;
## a dialog box should never display a multi-kilobyte blob.
func _truncate(s: String, limit := 300) -> String:
	if s.length() <= limit:
		return s
	return s.substr(0, limit) + ("... (truncated, %d chars)" % s.length())


# ── Completion / dispatch ─────────────────────────────────────────────────────

func _finish_success(text: String) -> void:
	var req := _current
	_current = {}
	_busy = false
	var cb: Callable = req.get("on_done", Callable())
	if cb.is_valid():
		cb.call(text)
	else:
		response_received.emit(text)
	_pump()


func _finish_error(error: String) -> void:
	var req := _current
	_current = {}
	_busy = false
	_dispatch_error(req, error)
	_pump()


func _dispatch_error(req: Dictionary, error: String) -> void:
	push_error("BedrockClient: " + error)
	var cb: Callable = req.get("on_error", Callable())
	if cb.is_valid():
		cb.call(error)
	else:
		request_failed.emit(error)
