class_name Card
extends RefCounted

var id: int
var suit: String
var rank: String

func _init(card_id: int, card_suit: String, card_rank: String):
	id = card_id
	suit = card_suit
	rank = card_rank

func _to_string() -> String:
	return "[%d] %s of %s" % [id, rank, suit]
