class_name Card
extends RefCounted

var id: int
var suit: String
var rank: String
var value: int
var is_ace: bool

func _init(card_id: int, card_suit: String, card_rank: String):
	id = card_id
	suit = card_suit
	rank = card_rank
	is_ace = (rank == "A")
	value = _determine_value()

func _determine_value() -> int:
	match rank:
		"A":
			return 11
		"J", "Q", "K":
			return 10
		_:
			return int(rank)

func _to_string() -> String:
	return "%s of %s" % [rank, suit]
