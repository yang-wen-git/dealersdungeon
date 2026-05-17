extends CanvasLayer

## Two-way chat overlay with the current enemy (the Mushroom dealer).
##
## Reuses NpcDialogBox (parchment panel + typewriter) to show the dealer's latest
## line, with a LineEdit for the player's replies. BedrockClient.generate() is
## single-shot (no server-side memory), so multi-turn context is kept client-side:
## the running transcript is folded into the prompt each turn. There is one enemy,
## so its persona is hardcoded here.
##
## Toggled by the "Talk" button in game.tscn's button bar; Esc closes it. Chat is
## pure flavor and has no mechanical effect on the blackjack hand.

const DIALOG_BOX_SCENE := preload("res://ui/scenes/npc_dialog_box.tscn")

## Persona / system prompt for the dealer. Hardcoded — there is one enemy.
@export_multiline var enemy_persona: String = "You are a sly, smug mushroom running a blackjack table deep in a dungeon. You taunt and banter with the challenger who is playing blackjack against you. Stay fully in character, never break character or mention being an AI, and reply in at most two short sentences."

## Top-left corner of the reply box on the 2048x1152 viewport.
@export var dialog_position: Vector2 = Vector2(674, 250)

## Max number of transcript lines kept as context (keeps the prompt small/cheap).
@export var history_limit: int = 8

@onready var _input: LineEdit = $Input

var _dialog_box: NpcDialogBox
var _history: PackedStringArray = PackedStringArray()
var _busy: bool = false


func _ready() -> void:
	# Build the reply box the same way toad_dialog.gd does. Set position (not
	# manual_position) before add_child: NpcDialogBox._ready() copies position
	# into manual_position, so anything set on manual_position now is overwritten.
	_dialog_box = DIALOG_BOX_SCENE.instantiate() as NpcDialogBox
	_dialog_box.name = "ReplyBox"
	_dialog_box.start_hidden = false
	_dialog_box.use_manual_position = true
	_dialog_box.max_width = 700.0
	_dialog_box.position = dialog_position
	add_child(_dialog_box)

	_input.text_submitted.connect(_on_submit)

	var talk_btn := _find_talk_button()
	if talk_btn != null:
		talk_btn.pressed.connect(toggle)
	else:
		push_warning("EnemyChatBox: TalkButton not found; chat can only be opened via code.")

	visible = false


## The Talk button lives in game.tscn's button bar. We're instanced as a child of
## the scene root, so it's reachable via the parent (with current_scene fallback).
func _find_talk_button() -> Button:
	const PATH := "UI Master/HBoxContainer/TalkButton"
	var parent := get_parent()
	if parent != null:
		var b := parent.get_node_or_null(PATH)
		if b is Button:
			return b as Button
	var scene := get_tree().current_scene
	if scene != null:
		var b2 := scene.get_node_or_null(PATH)
		if b2 is Button:
			return b2 as Button
	return null


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	if _history.is_empty():
		_dialog_box.show_text("...")
	_input.editable = not _busy
	_input.grab_focus()


func close() -> void:
	_input.release_focus()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_submit(text: String) -> void:
	var msg := text.strip_edges()
	if msg.is_empty() or _busy:
		return

	_append("Player: " + msg)
	_input.clear()
	_input.editable = false
	_busy = true
	_dialog_box.show_text("...")

	var on_success := func(reply: String):
		var clean := _strip_label(reply.strip_edges())
		_append("Dealer: " + clean)
		_dialog_box.show_text(clean)
		_finish()

	var on_error := func(_err: String):
		_dialog_box.show_text("*the mushroom just glares at you*")
		_finish()

	BedrockClient.generate(_build_prompt(), on_success, {
		"system": enemy_persona,
		"max_tokens": 120,
		"on_error": on_error,
	})


func _finish() -> void:
	_busy = false
	_input.editable = true
	if visible:
		_input.grab_focus()


func _append(line: String) -> void:
	_history.append(line)
	while _history.size() > history_limit:
		_history.remove_at(0)


func _build_prompt() -> String:
	var convo := "\n".join(_history)
	return "This is your ongoing conversation with the challenger at your blackjack table. Continue it, in character as the dealer.\n\n" + convo + "\nDealer:"


## The model sometimes echoes a leading speaker label — drop it so the box shows
## just the line.
func _strip_label(s: String) -> String:
	for prefix in ["Dealer:", "DEALER:", "Mushroom:", "Dealer -"]:
		if s.begins_with(prefix):
			return s.substr(prefix.length()).strip_edges()
	return s
