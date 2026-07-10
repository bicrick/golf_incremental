class_name UpgradeIcon
## Resolves 16×16 upgrade sprites from upgrade id.

const ICON_DIR := "res://assets/sprites/upgrades/"
const ICON_SIZE := Vector2i(16, 16)
## Shared medallion size for all upgrade tree nodes.
const DEFAULT_NODE_SIZE := Vector2(28, 28)
const NODE_HALF := Vector2(14, 14)

static var _cache: Dictionary = {}


static func path_for(upgrade_id: String) -> String:
	return ICON_DIR + upgrade_id + ".png"


static func load_texture(upgrade_id: String) -> Texture2D:
	if upgrade_id.is_empty():
		return null
	if _cache.has(upgrade_id):
		return _cache[upgrade_id]
	var path := path_for(upgrade_id)
	if not ResourceLoader.exists(path):
		push_warning("UpgradeIcon: missing texture for %s" % upgrade_id)
		return null
	var tex: Texture2D = load(path)
	_cache[upgrade_id] = tex
	return tex


static func center_in_node(icon_rect: TextureRect, _node_size: Vector2 = DEFAULT_NODE_SIZE) -> void:
	if icon_rect == null:
		return
	# PanelContainer expands children to the full content rect. Keep the TextureRect
	# filling the node and center the 16×16 texture inside it (STRETCH_KEEP paints
	# top-left and looks uncentered even when anchors are correct).
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.custom_minimum_size = Vector2.ZERO
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED


static func configure(
	icon_rect: TextureRect,
	upgrade_id: String,
	node_size: Vector2 = DEFAULT_NODE_SIZE
) -> void:
	if icon_rect == null:
		return
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.texture = load_texture(upgrade_id)
	center_in_node(icon_rect, node_size)
