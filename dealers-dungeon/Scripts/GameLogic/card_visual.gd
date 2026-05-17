extends Node2D

func set_front(texture_path: String):
	self.texture = load(texture_path)

func set_back():
	self.texture = load("res://Sprites/Cards/Card_Back_4.png")
