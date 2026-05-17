extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var chips_label = $ChipsLabel
@onready var bet_label = $BetLabel

func update_score(player_score, dealer_score):
	score_label.text = "Score: " + str(player_score)
	
func update_chips(chips, bet):
	chips_label.text= "Chips: " + str(chips)
	bet_label.text = "Bet: " + str(bet)

func _on_hit_pressed():
	pass

func _on_stand_pressed():
	pass
	
func _on_split_pressed():
	pass
	
