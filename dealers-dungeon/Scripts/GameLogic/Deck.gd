class_name Deck
extends RefCounted

var registry: CardRegistry
var order: Array[int] = []

func _init(card_registry: CardRegistry):
	registry = card_registry
	order = registry.cards.keys().duplicate()

func shuffle() -> void:
	order.shuffle()

func draw() -> Card:
	if order.is_empty():
		return null
	var card_id = order.pop_back()
	return registry.get_card(card_id)

func peek_top() -> Card:
	if order.is_empty():
		return null
	return registry.get_card(order.back())

func remaining() -> int:
	return order.size()
