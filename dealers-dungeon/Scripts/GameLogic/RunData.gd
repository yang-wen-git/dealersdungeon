extends Node

var registry: CardRegistry
var player: PlayerData
var inventory: InventoryData

var current_stage: int = 1
var current_encounter: int = 0
var max_encounters_per_stage: int = 3
var player_card_ids: Array[int] = []

func _ready():
	start_new_run()

func start_new_run() -> void:
	registry = CardRegistry.new()
	registry.build_standard_deck()
	player = PlayerData.new()
	inventory = InventoryData.new()
	current_stage = 1
	current_encounter = 0
	build_starter_deck()

func reset() -> void:
	start_new_run()

func build_starter_deck() -> void:
	player_card_ids.clear()
	for key in registry.cards.keys():
		player_card_ids.append(key)

func add_card(card: Card) -> void:
	registry.register(card)
	player_card_ids.append(card.id)
	print("Added %s to your deck!" % card)

func remove_card(card_id: int) -> void:
	player_card_ids.erase(card_id)
	print("Removed %s from your deck!" % registry.get_card(card_id))

func upgrade_card(card_id: int, new_value: int) -> void:
	var card = registry.get_card(card_id)
	if card:
		var old_value = card.value
		card.value = new_value
		print("Upgraded %s: value %d → %d" % [card, old_value, new_value])

func get_card_count() -> int:
	return player_card_ids.size()

func create_battle_deck() -> Deck:
	var battle_deck = Deck.new(registry)
	battle_deck.draw_pile.clear()
	for card_id in player_card_ids:
		battle_deck.draw_pile.append(card_id)
	battle_deck.shuffle()
	return battle_deck

func add_gold(amount: int) -> void:
	player.money += amount
	print("+ %d gold (Total: %d)" % [amount, player.money])

func spend_gold(amount: int) -> bool:
	if player.money >= amount:
		player.money -= amount
		print("- %d gold (Total: %d)" % [amount, player.money])
		return true
	print("Not enough gold! Need %d, have %d." % [amount, player.money])
	return false

func add_item(item: ItemData) -> bool:
	var success = inventory.add_item(item, player)
	if success and item.type == ItemData.ItemType.PASSIVE:
		player.add_passive_bonus(item.effect, item.value)
	return success

func advance_encounter() -> void:
	current_encounter += 1
	if current_encounter >= max_encounters_per_stage:
		current_encounter = 0
		current_stage += 1
		print("=== STAGE %d ===" % current_stage)

func is_run_over() -> bool:
	return player.health <= 0

func print_deck() -> void:
	print("=== Your Deck (%d cards) ===" % get_card_count())
	for card_id in player_card_ids:
		var card = registry.get_card(card_id)
		print("	%s (value: %d)" % [card, card.value])

func print_status() -> void:
	print("=== Run Status ===")
	print("	HP: %d/%d" % [player.health, player.max_health])
	print("	Gold: %d" % player.money)
	print("	Damage: %d" % player.get_damage())
	print("	Defense: %.1f" % player.get_defense())
	print("	Deck: %d cards" % get_card_count())
	print("	Stage: %d | Encounter: %d/%d" % [current_stage, current_encounter, max_encounters_per_stage])

func get_stage_encounters() -> Array[EncounterData]:
	var encounters: Array[EncounterData] = []

	if current_stage == 1:
		encounters.append(EncounterData.new("Easy Fight", [
			["Rookie Dealer", 16, 80, 8],
		]))
		encounters.append(EncounterData.new("Double Trouble", [
			["Dealer A", 17, 90, 10],
			["Dealer B", 16, 70, 8],
		]))
		encounters.append(EncounterData.new("Stage 1 Boss", [
			["Pit Boss", 18, 150, 15],
		]))
	elif current_stage == 2:
		encounters.append(EncounterData.new("Veteran Dealers", [
			["Sharp Eye", 17, 100, 12],
			["Card Shark", 18, 110, 14],
		]))
		encounters.append(EncounterData.new("The Trio", [
			["Dealer X", 17, 90, 10],
			["Dealer Y", 16, 85, 10],
			["Dealer Z", 18, 95, 12],
		]))
		encounters.append(EncounterData.new("Stage 2 Boss", [
			["High Roller", 19, 200, 20],
		]))

	return encounters

func get_current_encounter() -> EncounterData:
	var encounters = get_stage_encounters()
	if current_encounter < encounters.size():
		return encounters[current_encounter]
	return null
