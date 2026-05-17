class_name NpcDialogBox
extends Control

## Reusable NPC dialog box. The width is fixed (`max_width`); the box grows and
## shrinks in HEIGHT to exactly fit whatever text it is given, then re-anchors
## itself on screen.

enum Anchor {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	CENTER,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT,
}

@export var max_width: float = 450.0
@export var placement: int = Anchor.BOTTOM_CENTER
@export var anchor_point: Vector2 = Vector2(1024, 980)
@export var screen_margin: float = 24.0
@export var start_hidden: bool = true

## Characters per second for the typewriter reveal. 0 = instant (no animation).
@export var typewriter_cps: float = 40.0

## Path to your parchment/paper panel texture.
@export var panel_texture_path: String = "res://assets/PaperUiPanelCartoony.png"

## Path to your pixel font file (Pixelify Sans from Google Fonts).
@export var font_path: String = "res://assets/fonts/PixelifySans-Regular.ttf"

## Font size for dialog text.
@export var font_size: int = 20

## Text color.
@export var text_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## 9-slice texture margins.
@export var texture_margin_left: float = 40.0
@export var texture_margin_right: float = 40.0
@export var texture_margin_top: float = 40.0
@export var texture_margin_bottom: float = 40.0

## Content margins (inner padding).
@export var content_margin_left: float = 48.0
@export var content_margin_right: float = 15.0
@export var content_margin_top: float = 25.0
@export var content_margin_bottom: float = 25.0

@onready var _panel: PanelContainer = $Panel
@onready var _label: RichTextLabel = $Panel/Label

## Tracks whether the typewriter is currently revealing text.
var _is_typing: bool = false

## When true, the current typewriter animation will skip to the end.
var _skip_requested: bool = false


func _ready() -> void:
	_apply_theme()

	var pad_x := content_margin_left + content_margin_right
	_label.custom_minimum_size.x = maxf(0.0, max_width - pad_x)

	_panel.resized.connect(_on_panel_resized)

	if start_hidden:
		visible = false


func _apply_theme() -> void:
	var sb := StyleBoxTexture.new()
	var tex := load(panel_texture_path) as Texture2D
	if tex:
		sb.texture = tex
	else:
		push_warning("NpcDialogBox: Could not load panel texture at '%s'" % panel_texture_path)

	sb.texture_margin_left = texture_margin_left
	sb.texture_margin_right = texture_margin_right
	sb.texture_margin_top = texture_margin_top
	sb.texture_margin_bottom = texture_margin_bottom

	sb.content_margin_left = content_margin_left
	sb.content_margin_right = content_margin_right
	sb.content_margin_top = content_margin_top
	sb.content_margin_bottom = content_margin_bottom

	_panel.add_theme_stylebox_override("panel", sb)

	var font := load(font_path) as Font
	if font:
		_label.add_theme_font_override("normal_font", font)
		_label.add_theme_font_override("bold_font", font)
		_label.add_theme_font_override("italics_font", font)
		_label.add_theme_font_override("mono_font", font)
	else:
		push_warning("NpcDialogBox: Could not load font at '%s'" % font_path)

	_label.add_theme_font_size_override("normal_font_size", font_size)
	_label.add_theme_font_size_override("bold_font_size", font_size)
	_label.add_theme_font_size_override("italics_font_size", font_size)
	_label.add_theme_font_size_override("mono_font_size", font_size)

	_label.add_theme_color_override("default_color", text_color)


## Show NPC text with typewriter effect.
func show_text(text: String) -> void:
	# If already typing, skip the current animation instantly.
	if _is_typing:
		_skip_requested = true
		# Wait for the current coroutine to finish.
		await get_tree().process_frame

	_label.text = _sanitize(text)
	visible = true

	# First, let the label lay out at FULL text so the panel sizes correctly.
	_label.visible_ratio = 1.0
	await _recompute()

	# Now run the typewriter reveal.
	if typewriter_cps > 0.0:
		await _typewriter_reveal()
	else:
		_label.visible_ratio = 1.0


## Skip the typewriter animation and show all text immediately.
## Call this when the player presses a button to rush the text.
func skip_typewriter() -> void:
	if _is_typing:
		_skip_requested = true


## Returns true if the typewriter is currently animating.
func is_typing() -> bool:
	return _is_typing


func _typewriter_reveal() -> void:
	_is_typing = true
	_skip_requested = false

	var total_chars := _label.get_total_character_count()
	if total_chars == 0:
		_is_typing = false
		return

	_label.visible_characters = 0
	var elapsed := 0.0

	while _label.visible_characters < total_chars:
		if _skip_requested:
			break

		elapsed += get_process_delta_time()
		var chars_to_show := int(elapsed * typewriter_cps)
		_label.visible_characters = mini(chars_to_show, total_chars)

		await get_tree().process_frame

	# Ensure all text is visible at the end.
	_label.visible_characters = -1  # -1 means "show all"
	_label.visible_ratio = 1.0
	_is_typing = false
	_skip_requested = false


func clear() -> void:
	_label.text = ""
	_label.visible_characters = -1
	await _recompute()


func show_box() -> void:
	visible = true
	await _recompute()


func hide_box() -> void:
	visible = false


func _recompute() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_panel.reset_size()
	size = _panel.size
	_reposition()


func _on_panel_resized() -> void:
	size = _panel.size
	_reposition()


func _reposition() -> void:
	var vp := get_viewport_rect().size
	var bs := size
	var pos := anchor_point

	match placement:
		Anchor.TOP_LEFT:
			pass
		Anchor.TOP_CENTER:
			pos -= Vector2(bs.x * 0.5, 0.0)
		Anchor.TOP_RIGHT:
			pos -= Vector2(bs.x, 0.0)
		Anchor.CENTER:
			pos -= bs * 0.5
		Anchor.BOTTOM_LEFT:
			pos -= Vector2(0.0, bs.y)
		Anchor.BOTTOM_CENTER:
			pos -= Vector2(bs.x * 0.5, bs.y)
		Anchor.BOTTOM_RIGHT:
			pos -= bs

	var max_x := maxf(screen_margin, vp.x - bs.x - screen_margin)
	var max_y := maxf(screen_margin, vp.y - bs.y - screen_margin)
	pos.x = clampf(pos.x, screen_margin, max_x)
	pos.y = clampf(pos.y, screen_margin, max_y)

	position = pos.round()


func _sanitize(s: String) -> String:
	return s.replace("[", "[lb]")
