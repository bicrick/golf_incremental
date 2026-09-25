class_name StoryFindsDirector
extends Node3D
## v5 story finds on the fairway — sprites in the harvest mist, click to claim,
## target finds rung by landing balls. See docs/v5/03-systems.md.

signal find_clicked(find_id: String, claimable: bool)

const CLICK_MIN_RADIUS_PX := 16.0
const SPARKLE_PIXEL_SIZE := 0.03
const BOB_HZ := 0.9
const SPARKLE_HZ := 1.6
## Silhouette wash toward fog colour and alpha deep in the bank.
const SILHOUETTE_WASH := 0.82
const SILHOUETTE_MIN_ALPHA := 0.0
const SILHOUETTE_MAX_ALPHA := 0.55
const TARGET_RING_TEXTURE_PX := 64
const GREEN_PIXEL_SIZE := 0.15
## Strike (perspective) view: found landmarks are 90-400 yd away, so scale them
## up with distance to read on the horizon — the range visibly becomes a course.
const STRIKE_LANDMARK_SCALE_PER_100YD := 1.6
const STRIKE_LANDMARK_SCALE_MIN := 1.0
const FLAGSTICK_PIXEL_SIZE := 0.034

var _range_view: Node = null
var _fog = null # HarvestFog
var _entries: Dictionary = {} # id -> {sprite, sparkle, ring, def, pos}
var _green: Sprite3D = null
var _time := 0.0
var _pop_tweens: Dictionary = {}


func setup(range_view: Node, harvest_fog) -> void:
	_range_view = range_view
	_fog = harvest_fog
	name = "StoryFinds"
	_build()
	if not EventBus.fairway_impact.is_connected(_on_fairway_impact):
		EventBus.fairway_impact.connect(_on_fairway_impact)
	if not EventBus.story_find_found.is_connected(_on_find_found):
		EventBus.story_find_found.connect(_on_find_found)
	if not EventBus.story_find_triggered.is_connected(_on_find_triggered):
		EventBus.story_find_triggered.connect(_on_find_triggered)
	_refresh_textures()
	update(0.0)


func _tee_z() -> float:
	return _fog.tee_z() if _fog != null else RangeGrid.player_bay_origin().z


func find_world_position(id: String) -> Vector3:
	var def := StoryFinds.get_def(id)
	return Vector3(float(def.get("x", 0.0)), 0.0, _tee_z() - float(def.get("yards", 0.0)))


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_entries.clear()
	for def in StoryFinds.all():
		var id: String = def["id"]
		var pos := find_world_position(id)
		var sprite := Sprite3D.new()
		sprite.name = id
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.shaded = false
		sprite.double_sided = true
		sprite.pixel_size = (
			FLAGSTICK_PIXEL_SIZE if def["kind"] == "finale" else float(def.get("pixel_size", 0.024))
		)
		sprite.texture = _load_tex(String(def["sprite"]))
		## Draw props after the flat green / target rings (both transparent).
		sprite.render_priority = 2
		add_child(sprite)
		var entry := {"sprite": sprite, "def": def, "pos": pos, "sparkle": null, "ring": null}
		var sparkle := Sprite3D.new()
		sparkle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sparkle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sparkle.shaded = false
		sparkle.no_depth_test = true
		sparkle.render_priority = 3
		sparkle.pixel_size = SPARKLE_PIXEL_SIZE
		sparkle.texture = _load_tex("sparkle")
		sparkle.visible = false
		add_child(sparkle)
		entry["sparkle"] = sparkle
		if def["kind"] == "target":
			entry["ring"] = _make_target_ring(float(def.get("radius", 5.0)), pos)
		if def["kind"] == "finale":
			_green = _make_green(pos)
		_entries[id] = entry
		_place(entry)


func _load_tex(sprite_name: String) -> Texture2D:
	var path := StoryFinds.sprite_path(sprite_name)
	if not ResourceLoader.exists(path):
		push_warning("StoryFindsDirector: missing sprite %s" % path)
		return null
	return load(path)


func _place(entry: Dictionary) -> void:
	var sprite: Sprite3D = entry["sprite"]
	var pos: Vector3 = entry["pos"]
	var h := 0.0
	if sprite.texture != null:
		h = float(sprite.texture.get_height()) * sprite.pixel_size
	sprite.position = pos + Vector3(0.0, h * 0.5 - 0.04, 0.0)
	entry["height"] = h
	var sparkle: Sprite3D = entry["sparkle"]
	sparkle.position = pos + Vector3(0.0, h + 0.25, 0.0)


func _make_green(pos: Vector3) -> Sprite3D:
	var green := Sprite3D.new()
	green.name = "FirstGreen"
	green.axis = Vector3.AXIS_Y
	green.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	green.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	green.shaded = false
	green.double_sided = true
	green.pixel_size = GREEN_PIXEL_SIZE
	green.texture = _load_tex("green_disc")
	green.position = pos + Vector3(0.0, 0.03, 0.0)
	green.render_priority = -1
	add_child(green)
	return green


func _make_target_ring(radius: float, pos: Vector3) -> Sprite3D:
	var n := TARGET_RING_TEXTURE_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			if d <= 1.0 and d >= 0.9:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.7, 0.9))
			elif d < 0.9 and int(round(d * 10.0)) % 3 == 0 and (x + y) % 4 == 0:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.7, 0.25))
	var ring := Sprite3D.new()
	ring.axis = Vector3.AXIS_Y
	ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ring.shaded = false
	ring.double_sided = true
	ring.texture = ImageTexture.create_from_image(img)
	ring.pixel_size = radius * 2.0 / float(n)
	ring.position = pos + Vector3(0.0, 0.02, 0.0)
	ring.visible = false
	add_child(ring)
	return ring


func _refresh_textures() -> void:
	for id in _entries:
		var entry: Dictionary = _entries[id]
		var def: Dictionary = entry["def"]
		var sprite: Sprite3D = entry["sprite"]
		var tex_name := String(def["sprite"])
		if GameState.is_find_found(id) or GameState.is_find_triggered(id):
			tex_name = String(def.get("sprite_found", tex_name))
		sprite.texture = _load_tex(tex_name)
		_place(entry)


# --- per-frame ----------------------------------------------------------------


func update(delta: float) -> void:
	_time += delta
	var harvest: bool = _fog != null and _fog.fog_amount() > 0.01
	var reveal: float = _fog.displayed_reveal_yards() if _fog != null else GameState.revealed_yards()
	var fog_col: Color = _fog.fog_color() if _fog != null else Color(0.78, 0.82, 0.74, 1.0)
	var tint: Color = _fog.atmosphere_tint() if _fog != null else Color.WHITE
	var story_open := GameState.tutorial_completed or GameState.story_complete
	for id in _entries:
		_update_entry(id, _entries[id], harvest, reveal, fog_col, tint, story_open)
	if _green != null:
		var show_green: bool = (
			GameState.is_find_found("first_green")
			or GameState.story_complete
			or (harvest and story_open and _green_yards() <= reveal + StoryFinds.SILHOUETTE_YARDS)
		)
		_green.visible = show_green
		if show_green:
			var t: float = 0.0 if GameState.is_find_found("first_green") or GameState.story_complete else _depth_t(_green_yards(), reveal, harvest)
			_green.modulate = _fog_wash(tint, fog_col, t, 1.0)


func _green_yards() -> float:
	return float(StoryFinds.get_def("first_green").get("yards", 382.0))


func _depth_t(yards: float, reveal: float, harvest: bool) -> float:
	if not harvest:
		return 0.0
	return clampf((yards - reveal) / StoryFinds.SILHOUETTE_YARDS, 0.0, 1.0)


func _fog_wash(tint: Color, fog_col: Color, t: float, alpha: float) -> Color:
	if t <= 0.001:
		var c := tint
		c.a = alpha
		return c
	var washed := tint.lerp(fog_col, SILHOUETTE_WASH * clampf(0.35 + t, 0.0, 1.0))
	washed.a = alpha * lerpf(SILHOUETTE_MAX_ALPHA, SILHOUETTE_MIN_ALPHA, t * t)
	return washed


func _update_entry(
	id: String,
	entry: Dictionary,
	harvest: bool,
	reveal: float,
	fog_col: Color,
	tint: Color,
	story_open: bool
) -> void:
	var sprite: Sprite3D = entry["sprite"]
	var sparkle: Sprite3D = entry["sparkle"]
	var ring: Sprite3D = entry["ring"]
	var def: Dictionary = entry["def"]
	var yards := float(def["yards"])
	var found := GameState.is_find_found(id)
	var persist := bool(def.get("persist", true))

	var show := false
	var silhouette_t := 0.0
	var claimable := false
	if found:
		show = persist
	elif story_open and harvest:
		if yards + StoryFinds.REVEAL_MARGIN_YARDS <= reveal:
			show = true
			claimable = true
		elif yards <= reveal + StoryFinds.SILHOUETTE_YARDS:
			show = true
			silhouette_t = clampf((yards - reveal) / StoryFinds.SILHOUETTE_YARDS, 0.05, 1.0)
	sprite.visible = show
	if show:
		sprite.modulate = _fog_wash(tint, fog_col, silhouette_t, 1.0)
		var landmark := 1.0
		if not harvest and found:
			landmark = clampf(yards / 100.0 * STRIKE_LANDMARK_SCALE_PER_100YD, STRIKE_LANDMARK_SCALE_MIN, 4.0)
			if String(def["kind"]) == "finale":
				landmark *= 1.5
		if not _pop_tweens.has(id) or not (_pop_tweens[id] as Tween).is_valid():
			sprite.scale = Vector3.ONE * landmark
		var h := float(entry.get("height", 0.0)) * landmark
		var base_y := float((entry["pos"] as Vector3).y) + h * 0.5 - 0.04
		sprite.position.y = base_y
	var target_waiting := (
		claimable and String(def["kind"]) == "target" and not GameState.is_find_triggered(id)
	)
	var ready := claimable and not target_waiting
	sparkle.visible = ready
	if ready:
		var phase := _time * TAU * SPARKLE_HZ + float(id.hash() % 7)
		var s := 0.65 + 0.35 * absf(sin(phase))
		sparkle.scale = Vector3.ONE * s
		sparkle.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(phase)))
		var h2 := float(entry.get("height", 0.0))
		sparkle.position.y = h2 + 0.25 + 0.08 * sin(_time * TAU * BOB_HZ)
	if ring != null:
		ring.visible = target_waiting
		if target_waiting:
			var pulse := 0.5 + 0.5 * sin(_time * TAU * 0.7)
			ring.modulate = Color(1, 1, 1, 0.35 + 0.35 * pulse)


# --- input ----------------------------------------------------------------------


## Harvest click: returns true if a find (claimable or hint) was under the pointer.
func try_harvest_click(screen_pos: Vector2, camera: Camera3D) -> bool:
	if camera == null:
		return false
	if not (GameState.tutorial_completed or GameState.story_complete):
		return false
	var best_id := ""
	var best_d := INF
	for id in _entries:
		var entry: Dictionary = _entries[id]
		var sprite: Sprite3D = entry["sprite"]
		if not sprite.visible or GameState.is_find_found(id):
			continue
		if not GameState.is_find_revealed(id):
			continue
		if camera.is_position_behind(sprite.global_position):
			continue
		var h := float(entry.get("height", 0.4))
		var center := camera.unproject_position(sprite.global_position)
		var top := camera.unproject_position(sprite.global_position + Vector3(0.0, h * 0.5, 0.0))
		var radius := maxf(CLICK_MIN_RADIUS_PX, center.distance_to(top) * 1.15)
		var d := screen_pos.distance_to(center)
		if d <= radius and d < best_d:
			best_d = d
			best_id = id
	if best_id.is_empty():
		return false
	var claimable := GameState.is_find_claimable(best_id)
	_pop(best_id)
	find_clicked.emit(best_id, claimable)
	return true


func _pop(id: String) -> void:
	var entry: Dictionary = _entries.get(id, {})
	if entry.is_empty():
		return
	var sprite: Sprite3D = entry["sprite"]
	if _pop_tweens.has(id) and (_pop_tweens[id] as Tween).is_valid():
		(_pop_tweens[id] as Tween).kill()
	sprite.scale = Vector3.ONE
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(sprite, "scale", Vector3.ONE * 1.18, 0.08)
	tw.tween_property(sprite, "scale", Vector3.ONE, 0.16)
	_pop_tweens[id] = tw


# --- events ---------------------------------------------------------------------


func _on_fairway_impact(world_pos: Vector3) -> void:
	for id in _entries:
		var def: Dictionary = _entries[id]["def"]
		if String(def["kind"]) != "target":
			continue
		if GameState.is_find_found(id) or GameState.is_find_triggered(id):
			continue
		var pos: Vector3 = _entries[id]["pos"]
		var flat := Vector2(world_pos.x - pos.x, world_pos.z - pos.z)
		if flat.length() <= float(def.get("radius", 5.0)):
			GameState.trigger_find(id)


func _on_find_triggered(id: String) -> void:
	_refresh_textures()
	_pop(id)
	var sfx := get_node_or_null("/root/SfxManager")
	if sfx != null and sfx.has_method("play_story_target_hit"):
		sfx.play_story_target_hit()


func _on_find_found(id: String) -> void:
	_refresh_textures()
	_pop(id)
