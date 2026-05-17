extends Control

# Card Slot 1
@onready var card1_img: TextureRect = $GridContainer/CardSlot1/Card1Img
@onready var card1_name: Label = $GridContainer/CardSlot1/CardName
@onready var card1_desc: Label = $GridContainer/CardSlot1/CardDesc
@onready var card1_price: Label = $GridContainer/CardSlot1/PriceLabel
@onready var card1_buy: Button = $GridContainer/CardSlot1/BuyButton

# Card Slot 2
@onready var card2_img: TextureRect = $GridContainer/CardSlot2/Card2Img
@onready var card2_name: Label = $GridContainer/CardSlot2/Card2Name
@onready var card2_desc: Label = $GridContainer/CardSlot2/Card2Desc
@onready var card2_price: Label = $GridContainer/CardSlot2/Price2Label
@onready var card2_buy: Button = $GridContainer/CardSlot2/BuyButton

# Card Slot 3
@onready var card3_img: TextureRect = $GridContainer/CardSlot3/Card3Img
@onready var card3_name: Label = $GridContainer/CardSlot3/Card3Name
@onready var card3_desc: Label = $GridContainer/CardSlot3/Card3DescLabel
@onready var card3_price: Label = $GridContainer/CardSlot3/PriceLabel
@onready var card3_buy: Button = $GridContainer/CardSlot3/BuyButton

@onready var continue_button: Button = $ContinueButton


var shop_items: Array[ItemData] = []

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	card1_buy.pressed.connect(_on_buy_1)
	card2_buy.pressed.connect(_on_buy_2)
	card3_buy.pressed.connect(_on_buy_3)
	load_shop()

func load_shop() -> void:
	shop_items = RunData.item_registry.get_shop_items()
	setup_slot(0, card1_img, card1_name, card1_desc, card1_price, card1_buy)
	setup_slot(1, card2_img, card2_name, card2_desc, card2_price, card2_buy)
	setup_slot(2, card3_img, card3_name, card3_desc, card3_price, card3_buy)

func setup_slot(index: int, img: TextureRect, name_label: Label, desc_label: Label, price_lbl: Label, buy_btn: Button) -> void:
	if index >= shop_items.size():
		img.visible = false
		name_label.text = ""
		desc_label.text = ""
		price_lbl.text = ""
		buy_btn.visible = false
		return

	var item = shop_items[index]
	img.texture = load(item.icon_path)
	img.visible = true
	name_label.text = item.item_name
	desc_label.text = item.description
	price_lbl.text = "%d chips" % item.cost

	if RunData.has_item(item.id) or RunData.player.money < item.cost:
		buy_btn.disabled = true
	else:
		buy_btn.disabled = false

func _on_buy_1() -> void:
	buy_item(0)

func _on_buy_2() -> void:
	buy_item(1)

func _on_buy_3() -> void:
	buy_item(2)

func buy_item(index: int) -> void:
	if index >= shop_items.size():
		return
	var item = shop_items[index]
	if RunData.buy_item(item.id):
		load_shop()

func _on_continue_pressed() -> void:
	print("Continue pressed!")
	get_tree().change_scene_to_file("res://ui/scenes/game.tscn")
