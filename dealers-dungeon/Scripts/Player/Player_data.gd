class_name PlayerData

var money: int = 0
var max_health: int = 100
var health: int = 100

var base_damage: int = 10
var bonus_damage: int = 0

var base_defense: float = 0.0
var bonus_defense: float = 0.0

func get_damage() -> int:
	return base_damage + bonus_damage

func get_defense() -> float:
	return base_defense + bonus_defense

func heal(amount: int):
	health += amount
	health = min(health, max_health)

func add_passive_bonus(effect: String, value: int):
	if effect == "damage":
		bonus_damage += value
	elif effect == "defense":
		bonus_defense += value
	elif effect == "max_health":
		max_health += value
		health += value
 
