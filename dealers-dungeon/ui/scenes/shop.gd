extends Control

@onready var continue_button: Button = $ContinueButton  # Adjust path to your button

func _ready():
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	print("=== SHOP ===")
	print("Gold: %d" % RunData.player.money)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/scenes/battle.tscn")  # Adjust to your battle scene path

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
	if event.keycode == KEY_C:
		get_tree().change_scene_to_file("res://ui/scenes/battle.tscn")  # Adjust path
