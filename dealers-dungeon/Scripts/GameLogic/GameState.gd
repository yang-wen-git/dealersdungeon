class_name GameState
extends Node

var registry: CardRegistry
var deck_order: Array = []

var player_hands: Array[Hand] = []
var enemies: Array[Enemy] = []

var current_round: int = 0
var game_active: bool = false
var player_turn: bool = false
var player_busted: bool = false
var player_stood: bool = false

func _ready():
	registry = CardRegistry.new()
	registry.build_standard_deck()
	start_new_game(2)

func start_new_game(enemy_count: int) -> void:
	# Shuffle deck only at game start
	deck_order.clear()
	for key in registry.cards.keys():
		deck_order.append(key)
	deck_order.shuffle()

	# Create enemies
	setup_enemies(enemy_count)

	current_round = 0
	start_new_round()

func setup_enemies(count: int) -> void:
	enemies.clear()
	count = clamp(count, 1, 3)

	# Example: different enemies with different stand values
	var enemy_configs = [
		["Dealer 1", 17],
		["Dealer 2", 16],
		["Dealer 3", 18],
	]

	for i in range(count):
		var config = enemy_configs[i]
		enemies.append(Enemy.new(config[0], config[1]))

func remove_enemy(index: int) -> void:
	if index >= 0 and index < enemies.size():
		enemies[index].is_active = false
		print("%s has been defeated!" % enemies[index].name)

func get_active_enemies() -> Array[Enemy]:
	var active: Array[Enemy] = []
	for enemy in enemies:
		if enemy.is_active:
			active.append(enemy)
	return active

func check_deck() -> void:
	# Reshuffle if deck is running low
	if deck_order.size() < 10:
		print("")
		print("--- Reshuffling deck ---")
		deck_order.clear()
		for key in registry.cards.keys():
			deck_order.append(key)
		deck_order.shuffle()

func start_new_round() -> void:
	var active_enemies = get_active_enemies()
	if active_enemies.is_empty():
		print("")
		print("=== YOU WIN THE GAME! All dealers defeated! ===")
		return

	current_round += 1
	game_active = true
	player_turn = true
	player_busted = false
	player_stood = false

	# Check if deck needs reshuffling
	check_deck()

	# Clear hands
	player_hands.clear()
	player_hands.append(Hand.new("Player"))

	for enemy in active_enemies:
		enemy.hand = Hand.new(enemy.name)

	# Deal 2 cards to player
	draw_to_hand(player_hands[0])
	draw_to_hand(player_hands[0])

	# Deal 2 cards to each active enemy
	for enemy in active_enemies:
		draw_to_hand(enemy.hand)
		draw_to_hand(enemy.hand)

	print("")
	print("=== ROUND %d ===" % current_round)
	print("")

	print_player_hand()
	print_all_dealer_hands_hidden()

	if check_blackjack():
		return

	print("")
	print("Your move: [H]it or [S]tand")

func check_blackjack() -> bool:
	var player_value = get_hand_value(player_hands[0])
	var player_has_bj = player_value == 21 and player_hands[0].size() == 2

	# Check if any dealer has blackjack
	var dealer_bj_list: Array[Enemy] = []
	for enemy in get_active_enemies():
		var val = get_hand_value(enemy.hand)
		if val == 21 and enemy.hand.size() == 2:
			dealer_bj_list.append(enemy)

	if player_has_bj and dealer_bj_list.size() > 0:
		print("")
		print("Blackjack push with: ")
		for enemy in dealer_bj_list:
			print("  ", enemy.name)
		print_all_dealer_hands_revealed()
		end_round()
		return true
	elif dealer_bj_list.size() > 0:
		print("")
		print("Dealer Blackjack!")
		for enemy in dealer_bj_list:
			print("  %s has Blackjack!" % enemy.name)
		print_all_dealer_hands_revealed()
		end_round()
		return true
	elif player_has_bj:
		print("")
		print("BLACKJACK! You win!")
		print_all_dealer_hands_revealed()
		end_round()
		return true

	return false

func hit() -> void:
	if not game_active or not player_turn:
		return

	draw_to_hand(player_hands[0])
	print("")
	print_player_hand()

	var player_value = get_hand_value(player_hands[0])

	if player_value > 21:
		player_busted = true
		player_turn = false
		print("")
		print("BUST! You went over 21. You lose!")
		print_all_dealer_hands_revealed()
		end_round()
	elif player_value == 21:
		print("You have 21!")
		stand()
	else:
		print("")
		print("Your move: [H]it or [S]tand")

func stand() -> void:
	if not game_active or not player_turn:
		return

	player_stood = true
	player_turn = false

	print("")
	print("You stand.")
	print("")

	dealer_turns()

func dealer_turns() -> void:
	var player_value = get_hand_value(player_hands[0])

	for enemy in get_active_enemies():
		print("--- %s's Turn (stands on %d) ---" % [enemy.name, enemy.stand_value])
		print_single_dealer_revealed(enemy)

		# Each enemy hits based on their own stand value
		while get_hand_value(enemy.hand) < enemy.stand_value:
			draw_to_hand(enemy.hand)
			print("%s hits." % enemy.name)
			print_single_dealer_revealed(enemy)

		var dealer_value = get_hand_value(enemy.hand)
		print("")

		if dealer_value > 21:
			print("%s busts! You win against %s!" % [enemy.name, enemy.name])
		elif dealer_value > player_value:
			print("%s wins with %d vs your %d." % [enemy.name, dealer_value, player_value])
		elif player_value > dealer_value:
			print("You beat %s! %d vs %d." % [enemy.name, player_value, dealer_value])
		else:
			print("Push with %s at %d." % [enemy.name, dealer_value])

		print("")

	end_round()

func end_round() -> void:
	game_active = false
	print("")
	print("Press [R] for next round or [Q] to quit.")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	if game_active and player_turn:
		if event.keycode == KEY_H:
			hit()
		elif event.keycode == KEY_S:
			stand()
	elif not game_active:
		if event.keycode == KEY_R:
			start_new_round()
		elif event.keycode == KEY_Q:
			print("Thanks for playing!")
			get_tree().quit()

# --- Utility ---

func draw_to_hand(hand: Hand) -> void:
	if deck_order.is_empty():
		check_deck()
	var card_id = deck_order.pop_back()
	hand.add_card(card_id)

func get_hand_value(hand: Hand) -> int:
	var total: int = 0
	var ace_count: int = 0

	for card_id in hand.cards:
		var card = registry.get_card(card_id)
		total += card.value
		if card.is_ace:
			ace_count += 1

	while total > 21 and ace_count > 0:
		total -= 10
		ace_count -= 1

	return total

func print_player_hand() -> void:
	print("Your hand:")
	for card_id in player_hands[0].cards:
		print("  ", registry.get_card(card_id))
	print("  Total: %d" % get_hand_value(player_hands[0]))

func print_all_dealer_hands_hidden() -> void:
	for enemy in get_active_enemies():
		print("%s's hand:" % enemy.name)
		var first_card = registry.get_card(enemy.hand.cards[0])
		print("  ", first_card)
		print("  [HIDDEN]")

func print_all_dealer_hands_revealed() -> void:
	for enemy in get_active_enemies():
		print_single_dealer_revealed(enemy)

func print_single_dealer_revealed(enemy: Enemy) -> void:
	print("%s's hand:" % enemy.name)
	for card_id in enemy.hand.cards:
		print("  ", registry.get_card(card_id))
	print("  Total: %d" % get_hand_value(enemy.hand))
