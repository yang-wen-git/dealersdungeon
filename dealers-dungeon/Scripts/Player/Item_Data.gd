class_name ItemData
extends RefCounted

enum ItemType {
	USABLE,
	PASSIVE
}

var id: int
var item_name: String
var type: ItemType
var effect: String
var description: String
var cost: int
var cooldown_max: int
var cooldown_current: int
var icon_path: String

func _init(_id: int, _name: String, _type: ItemType, _effect: String, _description: String, _cost: int, _cooldown: int = 0, _icon: String = ""):
	id = _id
	item_name = _name
	type = _type
	effect = _effect
	description = _description
	cost = _cost
	cooldown_max = _cooldown
	cooldown_current = 0
	icon_path = _icon

func is_ready() -> bool:
	return cooldown_current == 0

func use() -> void:
	cooldown_current = cooldown_max

func tick_cooldown() -> void:
	if cooldown_current > 0:
		cooldown_current -= 1
