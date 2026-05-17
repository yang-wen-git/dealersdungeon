class_name ItemRegistry
extends RefCounted

var all_items: Dictionary = {}

func _init():
	register_item(ItemData.new(
		0,
		"Double Down",
		ItemData.ItemType.PASSIVE,
		"double_damage",
		"Double your damage",
		50,
		0,
		"res://Sprites/Cards/DoubleDown.png"
	))
	register_item(ItemData.new(
		1,
		"Peek",
		ItemData.ItemType.USABLE,
		"peek",
		"See dealer's hidden card",
		75,
		3,
		"res://Sprites/Cards/Peek.png"
	))
	register_item(ItemData.new(
		2,
		"Insurance",
		ItemData.ItemType.USABLE,
		"insurance",
		"Protect from damage this round",
		30,
		3,
		"res://Sprites/Cards/Insurance.png"
	))

func register_item(item: ItemData) -> void:
	all_items[item.id] = item

func get_item(id: int) -> ItemData:
	return all_items[id]

func get_shop_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for key in all_items.keys():
		items.append(all_items[key])
	return items
