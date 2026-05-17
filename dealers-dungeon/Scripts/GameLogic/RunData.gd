extends Node

var registry: CardRegistry
var player: PlayerData
var inventory: InventoryData
var item_registry: ItemRegistry

var current_stage: int = 1
var current_encounter: int = 0
var max_encounters_per_stage: int = 3
var player_card_ids: Array[int] = []
var owned_items: Array[int] = []
var insurance_active: bool = false

func _ready():
	start_new_run()

func start_new_run() -> void:
	registry = CardRegistry.new()
	registry.build_standard_deck()
	player = PlayerData.new()
	inventory = InventoryData.new()
	item_registry = ItemRegistry.new()
	current_stage = 1
	current_encounter = 0
	owned_items.clear()
	insurance_active = false
	build_starter_deck()

func reset() -> void:
	start_new_run()

func build_starter_deck() -> void:
	player_card_ids.clear()
	for key in registry.cards.keys():
		player_card_ids.append(key)

# --- Deck Modification ---

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

# --- Gold ---

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

# --- Items ---

func buy_item(item_id: int) -> bool:
	var item = item_registry.get_item(item_id)
	if item == null:
		return false
	if owned_items.has(item_id):
		print("Already own %s!" % item.item_name)
		return false
	if not spend_gold(item.cost):
		return false
	owned_items.append(item_id)
	if item.type == ItemData.ItemType.PASSIVE:
		apply_passive(item)
	print("Bought %s!" % item.item_name)
	return true

func apply_passive(item: ItemData) -> void:
	if item.effect == "double_damage":
		player.bonus_damage += player.base_damage

func has_item(item_id: int) -> bool:
	return owned_items.has(item_id)

func get_owned_usable_items() -> Array[ItemData]:
	var usables: Array[ItemData] = []
	for item_id in owned_items:
		var item = item_registry.get_item(item_id)
		if item.type == ItemData.ItemType.USABLE:
			usables.append(item)
	return usables

func tick_item_cooldowns() -> void:
	for item_id in owned_items:
		var item = item_registry.get_item(item_id)
		if item.type == ItemData.ItemType.USABLE:
			item.tick_cooldown()

func use_item(item_id: int) -> bool:
	var item = item_registry.get_item(item_id)
	if item == null:
		return false
	if not item.is_ready():
		print("%s is on cooldown (%d rounds)" % [item.item_name, item.cooldown_current])
		return false
	item.use()
	return true

func activate_insurance() -> void:
	insurance_active = true

func clear_insurance() -> void:
	insurance_active = false

# --- Progression ---

func advance_encounter() -> void:
	current_encounter += 1
	if current_encounter >= max_encounters_per_stage:
		current_encounter = 0
		current_stage += 1
		print("=== STAGE %d ===" % current_stage)

func is_run_over() -> bool:
	return player.health <= 0

# --- View ---

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

# --- Encounters ---



func get_stage_encounters() -> Array[EncounterData]:
	var encounters: Array[EncounterData] = []

	if current_stage == 1:
		encounters.append(EncounterData.new("Easy Fight", [
			["Rookie Dealer", 16, 80, 8],
		]))
		encounters.append(EncounterData.new("Double Trouble", [
			["Veteran Dealer", 17, 90, 10],
		]))
		encounters.append(EncounterData.new("Stage 1 Boss", [
			["Pit Boss", 18, 150, 15],
		]))
	elif current_stage == 2:
		encounters.append(EncounterData.new("Veteran Dealers", [
			["Sharp Eye", 17, 100, 12],
		]))
		encounters.append(EncounterData.new("Card Shark", [
			["Card Shark", 18, 110, 14],
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
