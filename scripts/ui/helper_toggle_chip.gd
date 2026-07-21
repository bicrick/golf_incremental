extends PanelContainer
## Clickable chibi icon for a hired helper (Ratina / Rattlings) shown next to
## the currency panel — full color while active, a dark silhouette once
## toggled off. This is a non-destructive pause switch, not the one-time hire.

const COLOR_ACTIVE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_SILHOUETTE := Color(0.06, 0.06, 0.06, 1.0)
const COLOR_COUNT_ACTIVE := UiTheme.COLOR_PANEL_TEXT
const COLOR_COUNT_INACTIVE := UiTheme.COLOR_DISABLED
const SIZE_SOLO := Vector2(22, 22)
const SIZE_WITH_COUNT := Vector2(38, 24)

const RatinaSpriteFramesScript := preload("res://scripts/range/ratina_sprite_frames.gd")
const RATTLING_ICON_TEXTURE := "res://assets/sprites/rattling/rattling.png"

@export var helper_id: String = ""  # "ratina" or "rattlings"

@onready var _button: Button = $Button
@onready var _icon: TextureRect = $Button/Row/Icon
@onready var _count_label: Label = $Button/Row/CountLabel


func _ready() -> void:
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	PixelFont.apply_label(_count_label, 10)
	UiTheme.apply_panel_label(_count_label)
	_count_label.visible = helper_id == "rattlings"
	_button.custom_minimum_size = SIZE_WITH_COUNT if helper_id == "rattlings" else SIZE_SOLO
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_pressed)
	_icon.texture = _load_icon_texture()
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.helper_toggled.connect(_on_helper_toggled)
	_refresh()


func _load_icon_texture() -> Texture2D:
	match helper_id:
		"ratina":
			var sheet: Texture2D = load(RatinaSpriteFramesScript.IDLE_SHEET)
			return RatinaSpriteFramesScript.make_atlas_frame(sheet, RatinaSpriteFramesScript.IDLE_COLS, 0)
		"rattlings":
			return load(RATTLING_ICON_TEXTURE)
	return null


func _on_pressed() -> void:
	match helper_id:
		"ratina":
			GameState.set_ratina_active(not GameState.ratina_active)
		"rattlings":
			GameState.set_rattlings_active(not GameState.rattlings_active)
	_button.release_focus()


func _on_helper_toggled(helper: String, _active: bool) -> void:
	if helper == helper_id:
		_refresh()


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_refresh()


func _refresh() -> void:
	visible = _is_unlocked()
	if not visible:
		return
	var active := _is_active()
	_icon.modulate = COLOR_ACTIVE if active else COLOR_SILHOUETTE
	if helper_id == "rattlings":
		_count_label.text = "x%d" % int(GameState.rattling_stats.rattling_count)
		_count_label.add_theme_color_override(
			&"font_color", COLOR_COUNT_ACTIVE if active else COLOR_COUNT_INACTIVE
		)


func _is_unlocked() -> bool:
	match helper_id:
		"ratina":
			return GameState.ratina_unlocked
		"rattlings":
			return GameState.rattlings_unlocked
	return false


func _is_active() -> bool:
	match helper_id:
		"ratina":
			return GameState.ratina_active
		"rattlings":
			return GameState.rattlings_active
	return false
