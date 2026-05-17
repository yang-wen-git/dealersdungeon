class_name NPCDialog
extends Node2D

## The prompt sent to the AI. Fill this in per instance in the inspector.
@export_multiline var prompt: String = ""

## How close the player needs to be to interact (pixels).
@export var interaction_radius: float = 100.0

@onready var dialog_box: NpcDialogBox = $NpcDialogBox

var player_is_nearby: bool = false


func _ready() -> void:
	var area := Area2D.new()
	area.name = "InteractionArea"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if not player_is_nearby:
		return

	if event.is_action_pressed("ui_accept"):
		if dialog_box.is_typing():
			dialog_box.skip_typewriter()
		elif dialog_box.visible:
			dialog_box.hide_box()
		else:
			_talk()


func _talk() -> void:
	dialog_box.show_text("...")

	var on_success := func(text):
		dialog_box.show_text(text)

	var on_error := func(err):
		dialog_box.show_text("*stares silently*")

	BedrockClient.generate(prompt, on_success, { "on_error": on_error })


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_nearby = false
		dialog_box.hide_box()
