class_name Hand
extends RefCounted

var owner_name: String
var cards: Array = []

func _init(name: String):
	owner_name = name

func add_card(card_id: int) -> void:
	cards.append(card_id)

func remove_card(card_id: int) -> void:
	cards.erase(card_id)

func size() -> int:
	return cards.size()
