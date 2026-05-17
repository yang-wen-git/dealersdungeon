class_name GameState
extends Node

# --- State Variables ---

@onready var player_hand_area = $"../PlayerHandArea"
@onready var dealer_hand_area = $"../DealerHandArea"
var card_visual_scene = preload("res://ui/scenes/CardVisual.tscn")

var registry: CardRegistry
var run_data: RunData
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

# --- Initialization ---

func _ready():
	run_data = RunData.new()
	show_pre_battle()

# --- Pre-Battle ---

func show_pre_battle() -> void:
	var encounter = run_data.get_current_encounter()
	if encounter == null:
		print("=== No more encounters. You win! ===")
		return

	battle_active = false
	print("")
	print("=== UPCOMING BATTLE ===")
	print("	%s" % encounter.encounter_name)
	print("	Enemies:")
	for config in encounter.enemy_configs:
		print("		%s (stands on %d, HP: %d, DMG: %d)" % [config[0], config[1], config[2], config[3]])
	print("")
	run_data.print_status()
	print("")
	print("Press [B] to begin battle or [D] to view deck.")

func start_battle() -> void:
	var encounter = run_data.get_current_encounter()
	if encounter == null:
		return

	registry = run_data.registry
	deck = run_data.create_battle_deck()
	battle_active = true

	enemies.clear()
	for config in encounter.enemy_configs:
		var enemy = Enemy.new(config[0], config[1])
		enemy.max_health = config[2]
		enemy.health = config[2]
		enemy.damage = config[3]
		enemies.append(enemy)

	current_round = 0
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

	print("")
	print("=== ROUND %d ===" % current_round)
	print("	Cards remaining: %d" % deck.remaining())
	print("")

	print_player_hand()
	print_all_dealer_hands_hidden()

	update_card_visuals()

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
		end_round()
		return true

	if get_unresolved_enemies().is_empty():
		end_round()
		return true

	return false

func end_round() -> void:
	for hand in player_hands:
		deck.discard_hand(hand)
	for enemy in get_active_enemies():
		deck.discard_hand(enemy.hand)

	game_active = false

	# Check player death
	if run_data.player.health <= 0:
		print("")
		print("=== YOU DIED. Run over. ===")
		battle_active = false
		print("Press [Q] to quit.")
		return

	# Check all enemies dead
	if get_active_enemies().is_empty():
		print("")
		print("=== BATTLE WON! ===")
		battle_active = false
		run_data.advance_encounter()
		print("Press [N] for next encounter or [Q] to quit.")
		return

	print("")
	print("	Player HP: %d/%d" % [run_data.player.health, run_data.player.max_health])
	for enemy in get_active_enemies():
		print("	%s HP: %d/%d" % [enemy.name, enemy.health, enemy.max_health])
	print("")
	print("Press [R] for next round or [Q] to quit.")

# --- Player Actions ---

func hit() -> void:
	if not game_active or not player_turn:
		return

	var current_hand = player_hands[current_hand_index]
	draw_to_hand(current_hand)

	update_card_visuals()

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
	if not game_active or not player_turn:
		return

	print("")
	print("%s stands." % player_hands[current_hand_index].owner_name)
	advance_to_next_hand()

func split() -> void:
	if not game_active or not player_turn:
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
			print("")
			print("All hands busted!")
			print_all_dealer_hands_revealed()
			for enemy in get_unresolved_enemies():
				apply_enemy_attack(enemy)
			end_round()
		else:
			player_stood = true
			player_turn = false
			print("")
			dealer_turns()
	else:
		print("")
		print("=== Now playing %s ===" % player_hands[current_hand_index].owner_name)
		print_current_hand()
		print_split_prompt()

# --- Dealer Turn ---

func dealer_turns() -> void:
	for enemy in get_unresolved_enemies():
		print("--- %s's Turn (stands on %d) ---" % [enemy.name, enemy.stand_value])
		print_single_dealer_revealed(enemy)

		while get_hand_value(enemy.hand) < enemy.stand_value:
			draw_to_hand(enemy.hand)
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

	# Pre-battle screen
	if not battle_active:
		if event.keycode == KEY_B:
			start_battle()
		elif event.keycode == KEY_D:
			run_data.print_deck()
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
	var base = run_data.player.get_damage()
	# Future: apply item/buff modifiers here
	return base

func calculate_enemy_damage(enemy: Enemy) -> int:
	var base = enemy.damage
	# Future: apply player defense reduction here
	return base

func apply_player_attack(enemy: Enemy) -> void:
	var damage = calculate_player_damage()
	enemy.take_damage(damage)
	print("	You deal %d damage to %s! (HP: %d/%d)" % [damage, enemy.name, enemy.health, enemy.max_health])
	if enemy.health <= 0:
		remove_enemy(enemies.find(enemy))

func apply_enemy_attack(enemy: Enemy) -> void:
	var damage = calculate_enemy_damage(enemy)
	run_data.player.health -= damage
	run_data.player.health = max(run_data.player.health, 0)
	print("	%s deals %d damage to you! (HP: %d/%d)" % [enemy.name, damage, run_data.player.health, run_data.player.max_health])

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


#dont delete important function

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
