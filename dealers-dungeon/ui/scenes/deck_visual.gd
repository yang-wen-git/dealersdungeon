extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func set_card_back(texture: Texture2D):
	sprite.texture = texture
