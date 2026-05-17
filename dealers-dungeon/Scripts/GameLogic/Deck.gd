class_name Deck
extends RefCounted

var registry: CardRegistry
var draw_pile: Array[int] = []
var discard_pile: Array[int] = []
var removed_cards: Array[int] = []

func _init(card_registry: CardRegistry):
	registry = card_registry
	for key in registry.cards.keys():
		draw_pile.append(key)

func shuffle() -> void:
	draw_pile.shuffle()

func draw() -> int:
	if draw_pile.is_empty():
		reshuffle_discard()
	if draw_pile.is_empty():
		push_error("Deck is completely empty!")
		return -1
	return draw_pile.pop_back()

func reshuffle_discard() -> void:
	print("--- Reshuffling discard into draw pile ---")
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()

func discard(card_id: int) -> void:
	discard_pile.append(card_id)

func discard_hand(hand: Hand) -> void:
	for card_id in hand.cards:
		discard_pile.append(card_id)
	hand.cards.clear()

# --- Deck Building (Shop/Rewards) ---

func add_card(card: Card) -> void:
	registry.register(card)
	draw_pile.append(card.id)

func remove_card(card_id: int) -> void:
	draw_pile.erase(card_id)
	discard_pile.erase(card_id)
	removed_cards.append(card_id)

func upgrade_card(card_id: int, new_value: int) -> void:
	var card = registry.get_card(card_id)
	if card:
		card.value = new_value

# --- Viewing (for UI/shop) ---

func get_full_deck() -> Array[int]:
	var full: Array[int] = []
	full.append_array(draw_pile)
	full.append_array(discard_pile)
	return full

func remaining() -> int:
	return draw_pile.size()

func total_size() -> int:
	return draw_pile.size() + discard_pile.size()
