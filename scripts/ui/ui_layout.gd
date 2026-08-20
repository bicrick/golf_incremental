class_name UiLayout
extends RefCounted
## Shared viewport layout helpers for portrait / landscape.

const LANDSCAPE_SIZE := Vector2i(480, 270)
const PORTRAIT_SIZE := Vector2i(270, 480)


static func is_portrait(viewport: Viewport = null) -> bool:
	var size := viewport_size(viewport)
	return size.y > size.x


static func is_mobile_touch() -> bool:
	## Portrait web (phones) or any touchscreen device.
	if DisplayServer.is_touchscreen_available():
		return true
	return OS.has_feature("web") and is_portrait()


static func viewport_size(viewport: Viewport = null) -> Vector2:
	if viewport != null:
		return viewport.get_visible_rect().size
	## Fallback when no viewport is in hand (autoload / static callers).
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_visible_rect().size
	return Vector2(LANDSCAPE_SIZE)


static func content_scale_size_for_viewport(size: Vector2) -> Vector2i:
	if size.y > size.x:
		return PORTRAIT_SIZE
	return LANDSCAPE_SIZE
