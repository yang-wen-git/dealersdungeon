extends Control

@onready var ace: Sprite2D = $Ace
@onready var king: Sprite2D = $King
@onready var joker: Sprite2D = $Joker

# Floating animation state: [node, base_y, amplitude_px, frequency_hz, phase_rad]
# Cards are 120° apart in phase so they're never in sync.
var _float_cards: Array = []
var _float_time: float = 0.0

func _ready():
	$PlayButton.pressed.connect(_on_play_pressed)
	$EndButton.pressed.connect(_on_end_pressed)

	_float_cards = [
		[ace,   ace.position.y,   10.0, 0.38, 0.0],
		[king,  king.position.y,   8.0, 0.42, TAU / 3.0],
		[joker, joker.position.y, 12.0, 0.35, TAU * 2.0 / 3.0],
	]

func _process(delta: float) -> void:
	_float_time += delta
	for data in _float_cards:
		var node: Sprite2D = data[0]
		var base_y: float    = data[1]
		var amplitude: float = data[2]
		var frequency: float = data[3]
		var phase: float     = data[4]
		node.position.y = base_y + sin(_float_time * frequency * TAU + phase) * amplitude

func _on_play_pressed():
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")

func _on_end_pressed():
	get_tree().quit()
