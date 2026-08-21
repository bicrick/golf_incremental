class_name UiLayout
extends RefCounted
## Shared viewport layout helpers for portrait / landscape.

const LANDSCAPE_SIZE := Vector2i(480, 270)
const PORTRAIT_SIZE := Vector2i(270, 480)


static func is_portrait(viewport: Viewport = null) -> bool:
	var size := viewport_size(viewport)
	return size.y > size.x


static func is_mobile_touch() -> bool:
	## Tap-to-inspect UI for real phones/tablets. Do NOT use bare
	## DisplayServer.is_touchscreen_available() — macOS/Windows trackpads and
	## some laptop digitizers report touchscreen and would force inspect-then-buy
	## (breaking desktop single-click purchase).
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	## Portrait web covers phones whose UA does not set web_android/web_ios.
	if OS.has_feature("web") and is_portrait():
		return true
	return false


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
