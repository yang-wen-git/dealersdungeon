extends Node

## BedrockClient — Autoload singleton for AWS Bedrock (Amazon Nova) text generation.
##
## Registered as the "BedrockClient" autoload in project.godot, so it is reachable
## from any script without a reference. Two ways to call it:
##
##   # 1. Simple — listen on the global signals (good for one caller / quick tests):
##   BedrockClient.response_received.connect(_on_text)
##   BedrockClient.request_failed.connect(_on_error)
##   BedrockClient.invoke("Greet the player as a shady merchant.")
##
##   # 2. Recommended — per-request callback + a persona (good for many NPCs):
##   BedrockClient.generate(
##       "The player offers 3 gold for a rusty sword.",
##       func(text): dialog_box.show_text(text),
##       {
##           "system": "You are Grix, a greedy dungeon merchant. Reply in one sentence.",
##           "max_tokens": 256,
##           "on_error": func(err): dialog_box.show_text("...")
##       })
##
## Concurrent calls are safe: requests are queued because the underlying
## HTTPRequest node serves one request at a time.


# ── Config ────────────────────────────────────────────────────────────────────
# Loaded at runtime from aws_config.cfg (gitignored). See aws_config.cfg.example
# for the file format. Never hardcode credentials in this script.
# WARNING: Files under res:// are bundled into exported Godot builds by default.
# Do not ship aws_config.cfg inside an export. Before release, either exclude
# this file from export filters or move secrets to user://, environment
# variables, or a backend/token-vending flow.

const _CONFIG_PATH := "res://aws_config.cfg"

var _access_key := ""
var _secret_key := ""
var _region     := "us-west-2"             # override via aws_config.cfg
var _model_id   := "amazon.nova-lite-v1:0" # override via aws_config.cfg


# ── Signals ───────────────────────────────────────────────────────────────────
## Emitted when a request made via invoke() (no callback) succeeds.
signal response_received(text: String)

## Emitted when a request with no on_error callback fails. Carries a description.
signal request_failed(error: String)


# ── Internals ─────────────────────────────────────────────────────────────────
var _http: HTTPRequest
var _crypto := Crypto.new()
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
	_http.request_completed.connect(_on_request_completed)


func _load_config() -> void:
	var config := ConfigFile.new()
	var err := config.load(_CONFIG_PATH)
	if err != OK:
		push_error("BedrockClient: could not load %s (error %d). Copy aws_config.cfg.example to aws_config.cfg and fill it in." % [_CONFIG_PATH, err])
		return
	_access_key = config.get_value("aws", "access_key_id", "")
	_secret_key = config.get_value("aws", "secret_access_key", "")
	_region     = config.get_value("aws", "region", _region)
	_model_id   = config.get_value("aws", "model_id", _model_id)
	if _access_key.is_empty() or _secret_key.is_empty():
		push_error("BedrockClient: aws_config.cfg is missing access_key_id or secret_access_key.")


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

	if _access_key.is_empty() or _secret_key.is_empty():
		var bad: Dictionary = _queue.pop_front()
		_dispatch_error(bad, "AWS credentials not configured (see aws_config.cfg).")
		_pump()
		return

	_busy = true
	_current = _queue.pop_front()
	_send(_current)


func _send(req: Dictionary) -> void:
	_ensure_http()

	# Amazon Nova request schema. `content` must be an array of content blocks,
	# not a bare string.
	var inference := {"maxTokens": req["max_tokens"]}
	if req["temperature"] != null:
		inference["temperature"] = float(req["temperature"])

	var payload := {
		"messages": [{"role": "user", "content": [{"text": req["prompt"]}]}],
		"inferenceConfig": inference,
	}
	if not String(req["system"]).is_empty():
		payload["system"] = [{"text": req["system"]}]

	var body := JSON.stringify(payload)
	var host := "bedrock-runtime.%s.amazonaws.com" % _region

	# The model ID contains ":" which must be percent-encoded in the path.
	# AWS SigV4 then URI-encodes the path a SECOND time when building the
	# canonical request (this applies to every service except S3). So the wire
	# URL is single-encoded (.../amazon.nova-lite-v1%3A0/...) but the string we
	# sign uses the double-encoded form (.../amazon.nova-lite-v1%253A0/...).
	# Do not "simplify" these two into one path — that causes a 403.
	var enc_model      := _uri_encode_segment(_model_id)
	var request_path   := "/model/%s/invoke" % enc_model
	var canonical_path := "/model/%s/invoke" % _uri_encode_segment(enc_model)
	var url := "https://%s%s" % [host, request_path]
	var headers := _build_signed_headers("POST", host, canonical_path, body)

	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_finish_error("HTTPRequest node error code: %d" % err)


# ── AWS SigV4 signing ─────────────────────────────────────────────────────────
# AWS requires every request to be signed with HMAC-SHA256. This is a correct,
# minimal SigV4 implementation in pure GDScript — leave the byte/newline layout
# alone unless you know the SigV4 canonical-request spec.

## `canonical_path` must be the DOUBLE-URI-encoded path (see _send) — SigV4
## signs the re-encoded path for all services except S3.
func _build_signed_headers(method: String, host: String, canonical_path: String, body: String) -> PackedStringArray:
	# Current UTC time — AWS rejects requests skewed more than ~5 minutes.
	var unix_time := int(Time.get_unix_time_from_system())
	var dt        := Time.get_datetime_dict_from_unix_time(unix_time)
	var amz_date  := "%04d%02d%02dT%02d%02d%02dZ" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var date_str  := "%04d%02d%02d" % [dt.year, dt.month, dt.day]

	# Step 1: canonical request
	var body_hash         := _sha256_hex(body)
	var canonical_headers := "content-type:application/json\nhost:%s\nx-amz-date:%s\n" % [host, amz_date]
	var signed_headers    := "content-type;host;x-amz-date"
	var canonical_request := "%s\n%s\n\n%s\n%s\n%s" % [method, canonical_path, canonical_headers, signed_headers, body_hash]

	# Step 2: string to sign
	var cred_scope     := "%s/%s/bedrock/aws4_request" % [date_str, _region]
	var string_to_sign := "AWS4-HMAC-SHA256\n%s\n%s\n%s" % [amz_date, cred_scope, _sha256_hex(canonical_request)]

	# Step 3: signing key + signature
	var signing_key := _get_signing_key(date_str, _region)
	var signature   := _crypto.hmac_digest(HashingContext.HASH_SHA256, signing_key, string_to_sign.to_utf8_buffer()).hex_encode()

	# Step 4: Authorization header
	var auth := "AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s" % [
		_access_key, cred_scope, signed_headers, signature
	]

	# Accept is unsigned (not in SignedHeaders) — that is allowed by SigV4.
	return PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Amz-Date: " + amz_date,
		"Authorization: " + auth,
	])


func _get_signing_key(date_str: String, region: String) -> PackedByteArray:
	var k_secret  := ("AWS4" + _secret_key).to_utf8_buffer()
	var k_date    := _crypto.hmac_digest(HashingContext.HASH_SHA256, k_secret, date_str.to_utf8_buffer())
	var k_region  := _crypto.hmac_digest(HashingContext.HASH_SHA256, k_date, region.to_utf8_buffer())
	var k_service := _crypto.hmac_digest(HashingContext.HASH_SHA256, k_region, "bedrock".to_utf8_buffer())
	return          _crypto.hmac_digest(HashingContext.HASH_SHA256, k_service, "aws4_request".to_utf8_buffer())


func _sha256_hex(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


## URI-encodes a single path segment (e.g. the model ID).
## Reserved characters get percent-encoded (e.g. : → %3A).
## Do NOT pass a full path with slashes — only one segment at a time.
func _uri_encode_segment(segment: String) -> String:
	const SAFE := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
	var result := ""
	for c in segment:
		if c in SAFE:
			result += c
		else:
			for b in c.to_utf8_buffer():
				result += "%%%02X" % b
	return result


# ── Response handling ─────────────────────────────────────────────────────────

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw := body.get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish_error("HTTP %d — %s" % [response_code, raw])
		return

	var json := JSON.new()
	if json.parse(raw) != OK:
		_finish_error("Could not parse JSON response: " + raw)
		return

	# Amazon Nova response shape:
	# { "output": { "message": { "content": [{ "text": "..." }] } } }
	var data: Dictionary = json.get_data()
	var message: Dictionary = data.get("output", {}).get("message", {})
	var content: Array = message.get("content", [])

	if content.is_empty() or typeof(content[0]) != TYPE_DICTIONARY:
		_finish_error("Unexpected response shape: " + raw)
		return

	_finish_success(String(content[0].get("text", "")))


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
