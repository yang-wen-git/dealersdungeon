extends Control

@onready var music = $Music

func _ready():
	# Button Connections
	$PlayButton.pressed.connect(_on_play_pressed)
	$EndButton.pressed.connect(_on_end_pressed)
	
	# Hover FX
	$PlayButton.mouse_entered.connect(_on_play_hover)
	$PlayButton.mouse_exited.connect(_on_play_exit)
	
	# Music
	music.play()

func _on_play_hover():
	print("hovered!")
	var tween = create_tween()
	tween.tween_property($PlayButton, "modulate", Color(1.5, 1.5, 1.5), 0.1)

func _on_play_exit():
	var tween = create_tween()
	tween.tween_property($PlayButton, "modulate", Color(1, 1, 1), 0.1)

func _on_play_pressed():
	music.stop()
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")
	
func _on_end_pressed():
	get_tree().quit()
