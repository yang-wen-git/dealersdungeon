extends Control

@onready var result_label = $ResultLabel
@onready var score_label = $ScoreLabel

func _ready():
	$PlayAgainButton.pressed.connect(_on_play_again_pressed)
	$MainMenuButton.pressed.connect(_on_main_menu_pressed)

func show_result(won: bool, final_score: int):
	if won:
		result_label.text = "YOU WIN!"
		result_label.modulate = Color("#00ff88")
	else:
		result_label.text = "YOU LOSE!"
		result_label.modulate = Color("#ff4444")
	
	score_label.text = "Chips: " + str(final_score)
	
	# Punch in animation
	result_label.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.3)\
	.set_trans(Tween.TRANS_BOUNCE)

func _on_play_again_pressed():
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")
	
func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://ui/scenes/title_screen.tscn")
