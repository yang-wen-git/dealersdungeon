extends Control

@onready var chips_label = $ChipsLabel
@onready var grid = $GridContainer

var player_chips = 10

var cards = [
	{"name": "Double Down", "desc": "Double your bet", "price": 50, "texture": "res//assets/cards/powerup1.png"},
	{"name": "Peek", "desc": "See dealer card", "price": 75, "texture": "res://assets/cards/powerup2.png"},
	{"name": "Insurance", "desc": "Protect your bet", "price": 30, "texture": "res://assets/cards/powerup3.png"},
]

func _ready():
	chips_label.text = "Chips: " + str(player_chips)
	$ContinueButton.pressed.connect(_on_continue_pressed)
	load_cards()

func load_cards():
	for card in cards:
		var slot = create_card_slot(card)
		grid.add_child(slot)

func create_card_slot(card_data):
	var panel = Panel.new()
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var img = TextureRect.new()
	img.texture = load(card_data["texture"])
	vbox.add_child(img)
	
	var name_label = Label.new()
	name_label.text = card_data["desc"]
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = card_data["desc"]
	vbox.add_child(desc_label)
	
	var buy_btn = Button.new()
	buy_btn.text = "Buy"
	buy_btn.pressed.connect(func(): _on_buy_pressed(card_data))
	vbox.add_child(buy_btn)
	
	return panel

func _on_buy_pressed(card_data):
	if player_chips >= card_data["price"]:
		player_chips -= card_data["price"]
		chips_label.text = "Chips: " + str(player_chips)
		print("Bought: " + card_data["name"])
	else:
		print("Not enough chips!")
		
func _on_continue_pressed():
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")
