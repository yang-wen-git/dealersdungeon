extends Control

@onready var play_again_button: Button = $PlayAgainButton
@onready var main_menu_button: Button = $MainMenuButton

func _ready():
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_play_again_pressed() -> void:
	RunData.reset()
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")

func _on_main_menu_pressed() -> void:
	RunData.reset()
	get_tree().change_scene_to_file("res://ui/scenes/title_screen.tscn")
