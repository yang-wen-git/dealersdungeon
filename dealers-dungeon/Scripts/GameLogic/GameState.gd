class_name GameState
extends Node

# --- UI References ---
@onready var hit_button: Button = $"../UI Master/HBoxContainer/HitButton"
@onready var stand_button: Button = $"../UI Master/HBoxContainer/StandButton"
@onready var double_button: Button = $"../UI Master/HBoxContainer/DoubleButton"
@onready var new_round: Button = $"../UI Master/HBoxContainer/NewRound"
@onready var begin_battle: Button = $"../UI Master/HBoxContainer/BeginBattle"
@onready var dealer_score_label: Label = $"../UI Master/DealerScoreLabel"
@onready var score_label: Label = $"../UI Master/ScoreLabel"
@onready var p_layer_health: Label = $"../PlayerHand/PLayerHealth"
@onready var enemy_health: Label = $"../EnemyHand/EnemyHealth"
@onready var player_card_1: Sprite2D = $"../PlayerHand/PlayerCard1"
@onready var player_card_2: Sprite2D = $"../PlayerHand/PlayerCard2"
@onready var player_card_3: Sprite2D = $"../PlayerHand/PlayerCard3"
@onready var player_card_4: Sprite2D = $"../PlayerHand/PlayerCard4"
@onready var enemy_card_1: Sprite2D = $"../EnemyHand/EnemyCard1"
@onready var enemy_card_2: Sprite2D = $"../EnemyHand/EnemyCard2"
@onready var enemy_card_3: Sprite2D = $"../EnemyHand/EnemyCard3"
@onready var enemy_card_4: Sprite2D = $"../EnemyHand/EnemyCard4"
@onready var split_hand_card_1: Sprite2D = $"../SplitHand/SplitHandCard1"
@onready var split_hand_card_2: Sprite2D = $"../SplitHand/SplitHandCard2"
@onready var split_hand_card_3: Sprite2D = $"../SplitHand/SplitHandCard3"
@onready var split_hand_card_4: Sprite2D = $"../SplitHand/SplitHandCard4"
@onready var deck_visual: Sprite2D = $"../DeckVisual"

# --- State Variables ---

var card_sprites: CardSprites = CardSprites.new()

var registry: CardRegistry
var deck: Deck

var player_hands: Array[Hand] = []
var enemies: Array[Enemy] = []

var current_hand_index: int = 0
var has_split: bool = false
var current_round: int = 0
var battle_active: bool = false
var game_active: bool = false
var player_turn: bool = false
var player_busted: bool = false
var player_stood: bool = false
var _is_animating: bool = false

# --- Initialization ---

func _ready():
	hit_button.pressed.connect(_on_hit_pressed)
	stand_button.pressed.connect(_on_stand_pressed)
	double_button.pressed.connect(_on_split_pressed)
	new_round.pressed.connect(_on_new_round_pressed)
	begin_battle.pressed.connect(_on_begin_battle_pressed)
	hide_all_cards()
	hide_split_hand()
	set_buttons_visible(false)
	new_round.visible = false
	begin_battle.visible = true
	p_layer_health.text = ""
	enemy_health.text = ""
	score_label.text = ""
	dealer_score_label.text = ""
	show_pre_battle()

# --- Button Callbacks ---

func _on_hit_pressed() -> void:
	hit()

func _on_stand_pressed() -> void:
	stand()

func _on_split_pressed() -> void:
	split()

func _on_new_round_pressed() -> void:
	start_new_round()

func _on_begin_battle_pressed() -> void:
	start_battle()

# --- UI Update Functions ---

func get_player_card_sprites() -> Array[Sprite2D]:
	return [player_card_1, player_card_2, player_card_3, player_card_4]

func get_enemy_card_sprites() -> Array[Sprite2D]:
	return [enemy_card_1, enemy_card_2, enemy_card_3, enemy_card_4]

func get_split_card_sprites() -> Array[Sprite2D]:
	return [split_hand_card_1, split_hand_card_2, split_hand_card_3, split_hand_card_4]

func hide_all_cards() -> void:
	for sprite in get_player_card_sprites():
		sprite.visible = false
	for sprite in get_enemy_card_sprites():
		sprite.visible = false

func hide_split_hand() -> void:
	for sprite in get_split_card_sprites():
		sprite.visible = false

func set_buttons_visible(show: bool) -> void:
	hit_button.visible = show
	stand_button.visible = show
	double_button.visible = show

func update_health_ui() -> void:
	p_layer_health.text = "HP: %d/%d" % [RunData.player.health, RunData.player.max_health]
	if get_active_enemies().is_empty():
		enemy_health.text = ""
	else:
		var enemy = get_active_enemies()[0]
		enemy_health.text = "HP: %d/%d" % [enemy.health, enemy.max_health]

func update_player_hand_ui() -> void:
	var card_sprites_arr = get_player_card_sprites()
	var hand: Hand

	if has_split:
		hand = player_hands[current_hand_index]
	else:
		hand = player_hands[0]

	for i in range(4):
		if i < hand.cards.size():
			var card_id = hand.cards[i]
			card_sprites_arr[i].texture = card_sprites.get_texture(card_id)
			card_sprites_arr[i].visible = true
		else:
			card_sprites_arr[i].visible = false

	score_label.text = str(get_hand_value(hand))

func update_enemy_hand_ui_hidden() -> void:
	if enemies.is_empty():
		return
	var enemy = get_active_enemies()[0]
	var enemy_sprites = get_enemy_card_sprites()

	# Card 1: face up
	if enemy.hand.cards.size() >= 1:
		var card_id = enemy.hand.cards[0]
		enemy_sprites[0].texture = card_sprites.get_texture(card_id)
		enemy_sprites[0].visible = true
	else:
		enemy_sprites[0].visible = false

	# Card 2: card back
	if enemy.hand.cards.size() >= 2:
		enemy_sprites[1].texture = card_sprites.card_back
		enemy_sprites[1].visible = true
	else:
		enemy_sprites[1].visible = false

	# Cards 3-4: hidden
	enemy_sprites[2].visible = false
	enemy_sprites[3].visible = false

	dealer_score_label.text = "?"

func update_enemy_hand_ui_revealed() -> void:
	if enemies.is_empty():
		return
	var enemy = get_active_enemies()[0]
	var enemy_sprites = get_enemy_card_sprites()

	for i in range(4):
		if i < enemy.hand.cards.size():
			var card_id = enemy.hand.cards[i]
			enemy_sprites[i].texture = card_sprites.get_texture(card_id)
			enemy_sprites[i].visible = true
		else:
			enemy_sprites[i].visible = false

	dealer_score_label.text = str(get_hand_value(enemy.hand))

func update_split_hand_ui() -> void:
	if not has_split or player_hands.size() < 2:
		hide_split_hand()
		return

	var split_sprites = get_split_card_sprites()
	var other_hand_index = 0 if current_hand_index == 1 else 1
	var hand = player_hands[other_hand_index]

	for i in range(4):
		if i < hand.cards.size():
			split_sprites[i].texture = card_sprites.get_texture(hand.cards[i])
			split_sprites[i].visible = true
		else:
			split_sprites[i].visible = false

# --- Animations ---

# Deals the initial 4 cards in standard blackjack order with slide-in animations.
# P1 face-up → D1 face-up → P2 face-up → D2 face-DOWN (card back).
func deal_initial_cards_animated() -> void:
	_is_animating = true
	var active_enemies = get_active_enemies()
	var player_sprites = get_player_card_sprites()
	var enemy_sprites = get_enemy_card_sprites()

	const STAGGER: float = 0.18
	const DURATION: float = 0.25

	# Build sequence: [sprite, texture, delay]
	var sequence: Array = []
	sequence.append([player_sprites[0], card_sprites.get_texture(player_hands[0].cards[0]), 0.0])
	if not active_enemies.is_empty():
		sequence.append([enemy_sprites[0], card_sprites.get_texture(active_enemies[0].hand.cards[0]), STAGGER])
	sequence.append([player_sprites[1], card_sprites.get_texture(player_hands[0].cards[1]), STAGGER * 2])
	if not active_enemies.is_empty():
		sequence.append([enemy_sprites[1], card_sprites.card_back, STAGGER * 3])

	var last_tween: Tween = null
	for item in sequence:
		var sprite: Sprite2D = item[0]
		var texture: Texture2D = item[1]
		var delay: float = item[2]
		var final_pos: Vector2 = sprite.position

		sprite.visible = false
		sprite.texture = texture

		var _s := sprite
		var _fp := final_pos
		var tween = create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_callback(func():
			_s.position = _s.get_parent().to_local(deck_visual.global_position)
			_s.visible = true
		)
		tween.tween_property(_s, "position", _fp, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		last_tween = tween

	if last_tween:
		await last_tween.finished

	score_label.text = str(get_hand_value(player_hands[0]))
	dealer_score_label.text = "?"
	_is_animating = false


# Animates the most recently drawn player card sliding in from the deck position.
# Call after update_player_hand_ui() so the sprite is already at its final position.
func animate_player_hit_card(hand: Hand) -> void:
	_is_animating = true
	var new_index = hand.size() - 1
	if new_index < 0 or new_index >= 4:
		_is_animating = false
		return

	var sprite: Sprite2D = get_player_card_sprites()[new_index]
	var final_pos: Vector2 = sprite.position
	sprite.position = sprite.get_parent().to_local(deck_visual.global_position)
	sprite.visible = true

	var tween = create_tween()
	tween.tween_property(sprite, "position", final_pos, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_is_animating = false


# Flips the dealer's face-down card (sprite index 1) to reveal the actual card value.
func animate_dealer_card_reveal() -> void:
	var active_enemies = get_active_enemies()
	if active_enemies.is_empty():
		return
	var enemy = active_enemies[0]
	if enemy.hand.cards.size() < 2:
		return

	var sprite: Sprite2D = get_enemy_card_sprites()[1]
	var face_texture: Texture2D = card_sprites.get_texture(enemy.hand.cards[1])
	var original_scale_x: float = sprite.scale.x

	# Scale X to 0 (card turns sideways), swap texture, scale back to full (card faces forward)
	var tween = create_tween()
	tween.tween_property(sprite, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): sprite.texture = face_texture)
	tween.tween_property(sprite, "scale:x", original_scale_x, 0.12).set_trans(Tween.TRANS_QUAD)
	await tween.finished


# --- Pre-Battle ---

func show_pre_battle() -> void:
	var encounter = RunData.get_current_encounter()
	if encounter == null:
		print("=== No more encounters. You win! ===")
		return

	battle_active = false
	hide_all_cards()
	hide_split_hand()
	set_buttons_visible(false)
	new_round.visible = false
	begin_battle.visible = true
	score_label.text = ""
	dealer_score_label.text = ""

	print("")
	print("=== UPCOMING BATTLE ===")
	print("	%s" % encounter.encounter_name)
	print("	Enemies:")
	for config in encounter.enemy_configs:
		print("		%s (stands on %d, HP: %d, DMG: %d)" % [config[0], config[1], config[2], config[3]])
	print("")
	RunData.print_status()
	print("")
	print("Press [B] to begin battle or [D] to view deck.")

func start_battle() -> void:
	var encounter = RunData.get_current_encounter()
	if encounter == null:
		return

	registry = RunData.registry
	deck = RunData.create_battle_deck()
	battle_active = true
	begin_battle.visible = false

	enemies.clear()
	for config in encounter.enemy_configs:
		var enemy = Enemy.new(config[0], config[1])
		enemy.max_health = config[2]
		enemy.health = config[2]
		enemy.damage = config[3]
		enemies.append(enemy)

	current_round = 0
	update_health_ui()
	start_new_round()

# --- Enemy Management ---

func remove_enemy(index: int) -> void:
	if index >= 0 and index < enemies.size():
		enemies[index].is_active = false
		print("%s has been defeated!" % enemies[index].name)

func get_active_enemies() -> Array[Enemy]:
	var active: Array[Enemy] = []
	for enemy in enemies:
		if enemy.is_active:
			active.append(enemy)
	return active

func get_unresolved_enemies() -> Array[Enemy]:
	var unresolved: Array[Enemy] = []
	for enemy in get_active_enemies():
		if not enemy.round_resolved:
			unresolved.append(enemy)
	return unresolved

# --- Round Flow ---

func start_new_round() -> void:
	var active_enemies = get_active_enemies()
	if active_enemies.is_empty():
		print("")
		print("=== YOU WIN THE GAME! All dealers defeated! ===")
		return

	current_round += 1
	game_active = true
	player_turn = true
	player_busted = false
	player_stood = false
	current_hand_index = 0
	has_split = false

	player_hands.clear()
	player_hands.append(Hand.new("Player"))

	for enemy in active_enemies:
		enemy.hand = Hand.new(enemy.name)
		enemy.round_resolved = false

	draw_to_hand(player_hands[0])
	draw_to_hand(player_hands[0])

	for enemy in active_enemies:
		draw_to_hand(enemy.hand)
		draw_to_hand(enemy.hand)

	# Reset UI — buttons stay hidden until the deal animation finishes
	hide_all_cards()
	hide_split_hand()
	new_round.visible = false
	set_buttons_visible(false)
	update_health_ui()

	print("")
	print("=== ROUND %d ===" % current_round)
	print("	Cards remaining: %d" % deck.remaining())
	print("")

	print_player_hand()
	print_all_dealer_hands_hidden()

	# Animate the deal, then unlock player actions
	await deal_initial_cards_animated()

	set_buttons_visible(true)
	double_button.visible = can_split()

	if check_blackjack():
		return

	print_split_prompt()

func check_blackjack() -> bool:
	var player_value = get_hand_value(player_hands[0])
	var player_has_bj = player_value == 21 and player_hands[0].size() == 2

	var dealer_bj_list: Array[Enemy] = []
	for enemy in get_active_enemies():
		var val = get_hand_value(enemy.hand)
		if val == 21 and enemy.hand.size() == 2:
			dealer_bj_list.append(enemy)

	if dealer_bj_list.size() > 0:
		print("")
		for enemy in dealer_bj_list:
			if player_has_bj:
				print("Blackjack push with %s!" % enemy.name)
			else:
				print("%s has Blackjack! %s wins this round." % [enemy.name, enemy.name])
				apply_enemy_attack(enemy)
			print_single_dealer_revealed(enemy)
			enemy.round_resolved = true
		update_enemy_hand_ui_revealed()
		print("")

	if player_has_bj:
		var unresolved = get_unresolved_enemies()
		if unresolved.size() > 0:
			print("BLACKJACK! You win against:")
			for enemy in unresolved:
				print("	%s" % enemy.name)
				apply_player_attack(enemy)
				enemy.round_resolved = true
		elif dealer_bj_list.size() > 0:
			pass
		else:
			print("BLACKJACK! You win!")
		update_enemy_hand_ui_revealed()
		set_buttons_visible(false)
		end_round()
		return true

	if get_unresolved_enemies().is_empty():
		update_enemy_hand_ui_revealed()
		set_buttons_visible(false)
		end_round()
		return true

	return false

func end_round() -> void:
	for hand in player_hands:
		deck.discard_hand(hand)
	for enemy in get_active_enemies():
		deck.discard_hand(enemy.hand)

	game_active = false
	set_buttons_visible(false)
	update_health_ui()

	# Check player death - transition to death screen
	if RunData.player.health <= 0:
		print("")
		print("=== YOU DIED. Run over. ===")
		battle_active = false
		new_round.visible = false
		begin_battle.visible = false
		get_tree().change_scene_to_file("res://ui/scenes/game_over.tscn")
		return

	# Check all enemies dead - transition to shop
	if get_active_enemies().is_empty():
		print("")
		print("=== BATTLE WON! ===")
		battle_active = false
		RunData.advance_encounter()
		get_tree().change_scene_to_file("res://ui/scenes/shop.tscn")
		return

	print("")
	print("	Player HP: %d/%d" % [RunData.player.health, RunData.player.max_health])
	for enemy in get_active_enemies():
		print("	%s HP: %d/%d" % [enemy.name, enemy.health, enemy.max_health])
	print("")
	new_round.visible = true
	print("Press [R] for next round or [Q] to quit.")

# --- Player Actions ---

func hit() -> void:
	if not game_active or not player_turn or _is_animating:
		return

	var current_hand = player_hands[current_hand_index]
	draw_to_hand(current_hand)

	# Show all cards at their final positions, then animate just the new card
	update_player_hand_ui()
	double_button.visible = false

	await animate_player_hit_card(current_hand)

	print("")
	print_current_hand()

	var hand_value = get_hand_value(current_hand)

	if hand_value > 21:
		print("")
		print("%s BUSTS!" % current_hand.owner_name)
		advance_to_next_hand()
	elif hand_value == 21:
		print("%s has 21!" % current_hand.owner_name)
		advance_to_next_hand()
	else:
		print_split_prompt()

func stand() -> void:
	if not game_active or not player_turn or _is_animating:
		return

	print("")
	print("%s stands." % player_hands[current_hand_index].owner_name)
	advance_to_next_hand()

func split() -> void:
	if not game_active or not player_turn or _is_animating:
		return
	if not can_split():
		print("Cannot split this hand.")
		return

	has_split = true

	var original_hand = player_hands[0]
	var card_a = original_hand.cards[0]
	var card_b = original_hand.cards[1]

	player_hands.clear()

	var hand_one = Hand.new("Player Hand 1")
	hand_one.add_card(card_a)
	player_hands.append(hand_one)

	var hand_two = Hand.new("Player Hand 2")
	hand_two.add_card(card_b)
	player_hands.append(hand_two)

	draw_to_hand(hand_one)
	draw_to_hand(hand_two)

	current_hand_index = 0

	# Update UI for split
	update_player_hand_ui()
	update_split_hand_ui()
	double_button.visible = false

	print("")
	print("=== SPLIT! Playing two hands ===")
	print("")
	print_current_hand()
	print_split_prompt()

func can_split() -> bool:
	if has_split:
		return false
	if player_hands.size() > 1:
		return false
	var hand = player_hands[current_hand_index]
	if hand.size() != 2:
		return false
	var card_a = registry.get_card(hand.cards[0])
	var card_b = registry.get_card(hand.cards[1])
	return card_a.rank == card_b.rank

func advance_to_next_hand() -> void:
	current_hand_index += 1

	if current_hand_index >= player_hands.size():
		var all_busted = true
		for hand in player_hands:
			if get_hand_value(hand) <= 21:
				all_busted = false
				break

		if all_busted:
			player_busted = true
			player_turn = false
			update_enemy_hand_ui_revealed()
			set_buttons_visible(false)
			print("")
			print("All hands busted!")
			print_all_dealer_hands_revealed()
			for enemy in get_unresolved_enemies():
				apply_enemy_attack(enemy)
			end_round()
		else:
			player_stood = true
			player_turn = false
			set_buttons_visible(false)
			print("")
			dealer_turns()
	else:
		# Switching to next split hand
		update_player_hand_ui()
		update_split_hand_ui()
		print("")
		print("=== Now playing %s ===" % player_hands[current_hand_index].owner_name)
		print_current_hand()
		print_split_prompt()

# --- Dealer Turn ---

func dealer_turns() -> void:
	await animate_dealer_card_reveal()
	update_enemy_hand_ui_revealed()

	for enemy in get_unresolved_enemies():
		print("--- %s's Turn (stands on %d) ---" % [enemy.name, enemy.stand_value])
		print_single_dealer_revealed(enemy)

		while get_hand_value(enemy.hand) < enemy.stand_value:
			draw_to_hand(enemy.hand)
			update_enemy_hand_ui_revealed()
			print("%s hits." % enemy.name)
			print_single_dealer_revealed(enemy)

		var dealer_value = get_hand_value(enemy.hand)
		var enemy_won = false
		print("")

		if dealer_value > 21:
			print("%s busts!" % enemy.name)
			for hand in player_hands:
				if get_hand_value(hand) <= 21:
					print("	%s wins against %s!" % [hand.owner_name, enemy.name])
					apply_player_attack(enemy)
		else:
			for hand in player_hands:
				var hand_value = get_hand_value(hand)
				if hand_value > 21:
					if not enemy_won:
						print("	%s busted - %s wins." % [hand.owner_name, enemy.name])
						apply_enemy_attack(enemy)
						enemy_won = true
					else:
						print("	%s busted - %s already attacked." % [hand.owner_name, enemy.name])
				elif hand_value > dealer_value:
					print("	%s beats %s! %d vs %d." % [hand.owner_name, enemy.name, hand_value, dealer_value])
					apply_player_attack(enemy)
				elif dealer_value > hand_value:
					if not enemy_won:
						print("	%s loses to %s. %d vs %d." % [hand.owner_name, enemy.name, hand_value, dealer_value])
						apply_enemy_attack(enemy)
						enemy_won = true
					else:
						print("	%s loses to %s. %d vs %d. (already attacked)" % [hand.owner_name, enemy.name, hand_value, dealer_value])
				else:
					print("	%s pushes with %s at %d." % [hand.owner_name, enemy.name, dealer_value])

		print("")

	end_round()

# --- Input ---

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	# Ignore game hotkeys while a text field (e.g. the chat box) has focus, so
	# typing a message doesn't also trigger Hit/Stand/Split/etc.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return

	# Block all game hotkeys during card animations
	if _is_animating:
		return

	# Pre-battle screen
	if not battle_active:
		if event.keycode == KEY_B:
			start_battle()
		elif event.keycode == KEY_N:
			show_pre_battle()
		elif event.keycode == KEY_D:
			RunData.print_deck()
		elif event.keycode == KEY_Q:
			print("Thanks for playing!")
			get_tree().quit()
		return

	# During battle - player's turn
	if game_active and player_turn:
		if event.keycode == KEY_H:
			hit()
		elif event.keycode == KEY_S:
			stand()
		elif event.keycode == KEY_P:
			split()
	# Between rounds within a battle
	elif not game_active:
		if event.keycode == KEY_R:
			start_new_round()
		elif event.keycode == KEY_N:
			show_pre_battle()
		elif event.keycode == KEY_Q:
			print("Thanks for playing!")
			get_tree().quit()

# --- Utility ---

func draw_to_hand(hand: Hand) -> void:
	var card_id = deck.draw()
	if card_id == -1:
		push_error("No cards available!")
		return
	hand.add_card(card_id)

func get_hand_value(hand: Hand) -> int:
	var total: int = 0
	var ace_count: int = 0

	for card_id in hand.cards:
		var card = registry.get_card(card_id)
		total += card.value
		if card.is_ace:
			ace_count += 1

	while total > 21 and ace_count > 0:
		total -= 10
		ace_count -= 1

	return total

# --- Damage Pipeline ---

func calculate_player_damage() -> int:
	var base = RunData.player.get_damage()
	return base

func calculate_enemy_damage(enemy: Enemy) -> int:
	var base = enemy.damage
	return base

func apply_player_attack(enemy: Enemy) -> void:
	var damage = calculate_player_damage()
	enemy.take_damage(damage)
	print("	You deal %d damage to %s! (HP: %d/%d)" % [damage, enemy.name, enemy.health, enemy.max_health])
	update_health_ui()
	if enemy.health <= 0:
		remove_enemy(enemies.find(enemy))

func apply_enemy_attack(enemy: Enemy) -> void:
	var damage = calculate_enemy_damage(enemy)
	RunData.player.health -= damage
	RunData.player.health = max(RunData.player.health, 0)
	print("	%s deals %d damage to you! (HP: %d/%d)" % [enemy.name, damage, RunData.player.health, RunData.player.max_health])
	update_health_ui()

# --- Print Functions ---

func print_player_hand() -> void:
	for hand in player_hands:
		print("%s:" % hand.owner_name)
		for card_id in hand.cards:
			print("	", registry.get_card(card_id))
		print("	Total: %d" % get_hand_value(hand))

func print_current_hand() -> void:
	var hand = player_hands[current_hand_index]
	print("%s:" % hand.owner_name)
	for card_id in hand.cards:
		print("	", registry.get_card(card_id))
	print("	Total: %d" % get_hand_value(hand))

func print_split_prompt() -> void:
	print("")
	if can_split():
		print("Your move: [H]it, [S]tand, or [P]plit")
	else:
		print("Your move: [H]it or [S]tand")

func print_all_dealer_hands_hidden() -> void:
	for enemy in get_active_enemies():
		print("%s's hand:" % enemy.name)
		var first_card = registry.get_card(enemy.hand.cards[0])
		print("	", first_card)
		print("	[HIDDEN]")

func print_all_dealer_hands_revealed() -> void:
	for enemy in get_active_enemies():
		print_single_dealer_revealed(enemy)

func print_single_dealer_revealed(enemy: Enemy) -> void:
	print("%s's hand:" % enemy.name)
	for card_id in enemy.hand.cards:
		print("	", registry.get_card(card_id))
	print("	Total: %d" % get_hand_value(enemy.hand))
