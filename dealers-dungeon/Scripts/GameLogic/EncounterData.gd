class_name EncounterData
extends RefCounted

var encounter_name: String
var enemy_configs: Array = []  # Array of [name, stand_value, health, damage]

func _init(name: String, configs: Array):
	encounter_name = name
	enemy_configs = configs
