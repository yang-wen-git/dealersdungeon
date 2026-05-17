extends AnimatedSprite2D

func _ready():
	play("idle")
	animation_finished.connect(_on_animation_finished)

func take_damage_Anim():
	play("take_damage")

func do_damage_Anim():
	play("Attack")

func dies():
	play("Death")

# "take_damage"/"Attack"/"Death" are non-looping, so this fires when they end.
# "idle" loops (emits animation_looped instead), so it never reaches here.
func _on_animation_finished():
	match String(animation):
		"take_damage", "Attack":
			play("idle")
		"Death":
			visible = false
