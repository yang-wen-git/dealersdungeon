extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D

func set_front():
	print("Children: ", get_children())  # See what nodes actually exist
	print("Sprite: ", $Sprite2D) 

func set_back():
	sprite_2d.texture = load("res://Sprites/Cards/Card_Back_4.png")

func update_card_visuals() -> void:

	for child in player_hand_area.get_children():
		child.queue_free()

	for child in dealer_hand_area.get_children():
		child.queue_free()

	if player_hands.is_empty():
		return

	# Player cards
	for i in range(player_hands[0].cards.size()):

		var card_id = player_hands[0].cards[i]
		var card = registry.get_card(card_id)

		var visual = card_visual_scene.instantiate()

		visual.position = Vector2(i * 100, 0)

		visual.set_front(card.texture_path)

		player_hand_area.add_child(visual)

	# Dealer cards
	if enemies.is_empty():
		return

	for i in range(enemies[0].hand.cards.size()):

		var visual = card_visual_scene.instantiate()

		visual.position = Vector2(i * 100, 0)

		if i == 0:
			var card_id = enemies[0].hand.cards[i]
			var card = registry.get_card(card_id)

			visual.set_front(card.texture_path)
		else:
			visual.set_back()

		dealer_hand_area.add_child(visual)
