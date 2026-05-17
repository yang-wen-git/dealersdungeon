class_name CardRegistry
extends RefCounted

var cards: Dictionary = {}

func register(card: Card) -> void:
	cards[card.id] = card

func get_card(card_id: int) -> Card:
	return cards[card_id]

func build_standard_deck() -> void:
	var suits = ["Hearts", "Diamonds", "Clubs", "Spades"]
	var ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var card_id = 0
	for suit in suits:
		for rank in ranks:
			register(Card.new(card_id, suit, rank))
			card_id += 1
