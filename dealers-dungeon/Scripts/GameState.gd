class_name GameState
extends Node

var registry: CardRegistry
var deck_order: Array = []

var player_hands: Array[Hand] = []
var enemy_hands: Array[Hand] = []

var current_round: int = 0
var game_active: bool = false
var player_turn: bool = false
var player_busted: bool = false
var player_stood: bool = false

func _ready():
	registry = CardRegistry.new()
	registry.build_standard_deck()
	start_new_round()

func start_new_round() -> void:
	current_round += 1
	game_active = true
	player_turn = true
	player_busted = false
	player_stood = false

	# Clear old hands
	player_hands.clear()
	enemy_hands.clear()

	# Reset and shuffle deck
	deck_order.clear()
	for key in registry.cards.keys():
		deck_order.append(key)
	deck_order.shuffle()

	# Create hands
	player_hands.append(Hand.new("Player"))
	enemy_hands.append(Hand.new("Dealer"))

	# Deal 2 cards each
	draw_to_hand(player_hands[0])
	draw_to_hand(enemy_hands[0])
	draw_to_hand(player_hands[0])
	draw_to_hand(enemy_hands[0])

	print("")
	print("=== ROUND %d ===" % current_round)
	print("")

	# Show hands
	print_player_hand()
	print_dealer_hand_hidden()

	# Check for blackjack
	if check_blackjack():
		return

	print("")
	print("Your move: [H]it or [S]tand")

func check_blackjack() -> bool:
	var player_value = get_hand_value(player_hands[0])
	var dealer_value = get_hand_value(enemy_hands[0])
	var player_has_bj = player_value == 21 and player_hands[0].size() == 2
	var dealer_has_bj = dealer_value == 21 and enemy_hands[0].size() == 2

	# Dealer shows blackjack immediately
	if dealer_has_bj and player_has_bj:
		print("")
		print("Both have Blackjack! It's a push (tie)!")
		print_dealer_hand_revealed()
		end_round()
		return true
	elif dealer_has_bj:
		print("")
		print("Dealer has Blackjack! You lose!")
		print_dealer_hand_revealed()
		end_round()
		return true
	elif player_has_bj:
		print("")
		print("BLACKJACK! You win!")
		print_dealer_hand_revealed()
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
		print_dealer_hand_revealed()
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

	# Dealer reveals and plays
	dealer_turn()

func dealer_turn() -> void:
	print("--- Dealer's Turn ---")
	print_dealer_hand_revealed()

	# Dealer must hit on 16 or below, stand on 17+
	while get_hand_value(enemy_hands[0]) < 17:
		draw_to_hand(enemy_hands[0])
		print("Dealer hits.")
		print_dealer_hand_revealed()

	var dealer_value = get_hand_value(enemy_hands[0])
	var player_value = get_hand_value(player_hands[0])

	print("")

	if dealer_value > 21:
		print("Dealer busts! You win!")
	elif dealer_value > player_value:
		print("Dealer wins with %d vs your %d." % [dealer_value, player_value])
	elif player_value > dealer_value:
		print("You win with %d vs dealer's %d!" % [player_value, dealer_value])
	else:
		print("Push! It's a tie at %d." % player_value)

	end_round()

func end_round() -> void:
	game_active = false
	print("")
	print("Press [R] to play another round or [Q] to quit.")

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
		return
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

func print_dealer_hand_hidden() -> void:
	print("Dealer's hand:")
	var first_card = registry.get_card(enemy_hands[0].cards[0])
	print("  ", first_card)
	print("  [HIDDEN]")

func print_dealer_hand_revealed() -> void:
	print("Dealer's hand:")
	for card_id in enemy_hands[0].cards:
		print("  ", registry.get_card(card_id))
	print("  Total: %d" % get_hand_value(enemy_hands[0]))
