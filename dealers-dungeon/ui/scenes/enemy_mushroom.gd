extends AnimatedSprite2D

## Procedural "spore gas" attack VFX. No art asset is needed: the puff texture is
## generated in code as a tiny low-res blob and rendered with the project's
## nearest-neighbor filter, so it stays chunky/pixelated like the rest of the game.
## Swap _make_spore_texture() for `load("res://...png")` later if you draw real art.

var _spores: CPUParticles2D


func _ready():
	play("idle")
	animation_finished.connect(_on_animation_finished)
	_setup_spores()


func take_damage_Anim():
	play("take_damage")


func do_damage_Anim():
	play("Attack")
	_emit_spores()


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


# --- Spore gas ---

func _setup_spores() -> void:
	_spores = CPUParticles2D.new()
	_spores.name = "SporeGas"
	_spores.texture = _make_spore_texture()
	_spores.emitting = false
	_spores.one_shot = true
	_spores.explosiveness = 0.55
	_spores.amount = 80
	_spores.lifetime = 1.8
	# Particles live in world space so the cloud drifts on its own after it puffs.
	_spores.local_coords = false
	_spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_spores.emission_sphere_radius = 60.0
	# Billow down/forward toward the player's side of the table.
	_spores.direction = Vector2(0.5, 1.0)
	_spores.spread = 55.0
	_spores.gravity = Vector2(0, 35)
	_spores.initial_velocity_min = 90.0
	_spores.initial_velocity_max = 240.0
	_spores.damping_min = 30.0
	_spores.damping_max = 75.0
	_spores.angular_velocity_min = -120.0
	_spores.angular_velocity_max = 120.0
	# Each puff swells as it disperses.
	_spores.scale_amount_min = 11.0
	_spores.scale_amount_max = 24.0
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.4, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.3))
	_spores.scale_amount_curve = scale_curve
	# Sickly green: fades in fast, lingers, fades out.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.62, 0.92, 0.34, 0.0),
		Color(0.62, 0.92, 0.34, 0.85),
		Color(0.42, 0.70, 0.22, 0.55),
		Color(0.34, 0.58, 0.18, 0.0),
	])
	_spores.color_ramp = ramp
	_spores.z_index = 50

	# Parent to the unscaled "Mushroom" node (Enemy_Mushroom is scaled 10x, which
	# would multiply every distance/velocity). Emit from the mushroom's left side,
	# where it leans over farthest during the attack lunge, toward the player.
	_spores.position = position + Vector2(-300, 30)
	var host := get_parent()
	if host != null:
		host.add_child.call_deferred(_spores)


func _emit_spores() -> void:
	# Wait until ~1.75s into the Attack animation, the moment the mushroom is
	# leaning over the farthest left, then erupt.
	await get_tree().create_timer(1.75).timeout
	if _spores != null and _spores.is_inside_tree():
		_spores.restart()


# Small, low-res radial blob. Chunky when scaled up by the particle system.
func _make_spore_texture() -> ImageTexture:
	var s := 12
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5 - 0.5, s * 0.5 - 0.5)
	var r := s * 0.5
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(c)
			var a := clampf(1.0 - d / r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
