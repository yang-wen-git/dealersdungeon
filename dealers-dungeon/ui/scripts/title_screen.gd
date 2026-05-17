extends Control

func _ready():
	$VBOXContainer/PlayButton.pressed.connect(_on_play_pressed)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")
	
func _on_end_pressed():
	get_tree().quit()
