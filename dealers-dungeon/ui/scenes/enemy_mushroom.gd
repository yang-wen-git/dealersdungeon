extends AnimatedSprite2D

func _ready():
	play("idle")

func take_damage_Anim():
	play("take_damage")
	
func do_damage_Anim():
	play("Attack")
	
func dies():
	play("Death")
	self.visible = 0
