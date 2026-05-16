extends Node

var money: int = 0

var max_health: int = 100
var health: int = 100

var damage: int = 10
var defense: float = 0

func add_money(amount: int):
	money += amount

func take_damage(amount: int):
	var final_damage = max(amount * (1-defense), 0)
	health -= final_damage
	health = max(health, 0)	

func heal(amount: int):
	health += amount
	health = min(health, max_health)
