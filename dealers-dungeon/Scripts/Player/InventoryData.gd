class_name InventoryData

var max_slots: int = 5

var usable_items: Array[ItemData] = []
var passive_items: Array[ItemData] = []

func add_item(item: ItemData, player_data: PlayerData) -> bool:

	if item.type == ItemData.ItemType.USABLE:

		if usable_items.size() >= max_slots:
			print("Inventory full")
			return false

		usable_items.append(item)
		return true

	elif item.type == ItemData.ItemType.PASSIVE:

		passive_items.append(item)
		player_data.add_passive_bonus(item.effect, item.value)
		return true

	return false
