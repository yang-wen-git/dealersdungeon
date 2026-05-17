extends Control

@onready var restart_button: Button = $RestartButton

func _ready():
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	RunData.reset()
	get_tree().change_scene_to_file("res://ui/scenes/battle.tscn")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
	if event.keycode == KEY_R:
		RunData.reset()
		get_tree().change_scene_to_file("res://ui/scenes/battle.tscn")
