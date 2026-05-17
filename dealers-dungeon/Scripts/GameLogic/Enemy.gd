class_name Enemy
extends RefCounted

var name: String
var stand_value: int
var hand: Hand
var is_active: bool
var round_resolved: bool = false

var max_health: int = 100
var health: int = 100
var damage: int = 10
var defense: float = 0.0


func _init(enemy_name: String, enemy_stand_value: int = 17):
	name = enemy_name
	stand_value = enemy_stand_value
	hand = Hand.new(enemy_name)
	is_active = true

func take_damage(amount: int):
	var final_damage = max(amount * (1 - defense), 0)
	health -= final_damage
	health = max(health, 0)

func heal(amount: int):
	health += amount
	health = min(health, max_health)

func _to_string() -> String:
	return "%s (stands on %d)" % [name, stand_value]
