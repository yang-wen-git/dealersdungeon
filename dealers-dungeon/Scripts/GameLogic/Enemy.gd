class_name Enemy
extends RefCounted

var name: String
var stand_value: int
var hand: Hand
var is_active: bool

func _init(enemy_name: String, enemy_stand_value: int = 17):
	name = enemy_name
	stand_value = enemy_stand_value
	hand = Hand.new(enemy_name)
	is_active = true

func _to_string() -> String:
	return "%s (stands on %d)" % [name, stand_value]
