extends Node2D

@onready var music = $Music

func _ready():
	# Music
	music.play()
