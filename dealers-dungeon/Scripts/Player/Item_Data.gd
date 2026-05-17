class_name ItemData

enum ItemType {
	USABLE,
	PASSIVE
}

var item_name: String
var type: ItemType
var effect: String
var value: int

func _init(_name: String, _type: ItemType, _effect: String, _value: int):
	item_name = _name
	type = _type
	effect = _effect
	value = _value
