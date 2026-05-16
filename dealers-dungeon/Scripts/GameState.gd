class_name GameState
extends Node

var registry: CardRegistry
var deck_order: Array = []

var player_hands: Array[Hand] = []
var enemy_hands: Array[Hand] = []

func _ready():
	# Build deck
	registry = CardRegistry.new()
	registry.build_standard_deck()
	deck_order = registry.cards.keys().duplicate()
	deck_order.shuffle()

	# Create hands
	player_hands.append(Hand.new("Player 1"))
	enemy_hands.append(Hand.new("Enemy 1"))

	# Deal 5 cards each
	for i in range(2):
		draw_to_hand(player_hands[0])
		draw_to_hand(enemy_hands[0])

	# Print results
	print("=== GAME START ===")
	print_hand(player_hands[0])
	print_hand(enemy_hands[0])
	print("Deck remaining: ", deck_order.size())

func draw_to_hand(hand: Hand) -> void:
	if deck_order.is_empty():
		return
	var card_id = deck_order.pop_back()
	hand.add_card(card_id)

func print_hand(hand: Hand) -> void:
	print(hand.owner_name + "'s hand:")
	for card_id in hand.cards:
		print("  ", registry.get_card(card_id))
