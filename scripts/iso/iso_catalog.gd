class_name IsoCatalog
extends RefCounted
## Data-driven building/prop definitions for the isometric build view.
## Footprints are in RangeGrid / TileMap cells (SUBCELLS=1).

const ENTRIES := {
	&"pine_tree": {
		"display_name": "Pine Tree",
		"texture": "res://assets/sprites/iso/props/pine_tree.png",
		"footprint": Vector2i(1, 1),
		"anchor_offset": Vector2(0, -56),
		"scale": 1.0,
		"cost": 0,
	},
}


static func has(id: StringName) -> bool:
	return ENTRIES.has(id)


static func get_entry(id: StringName) -> Dictionary:
	if not ENTRIES.has(id):
		return {}
	return ENTRIES[id]


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in ENTRIES.keys():
		ids.append(key as StringName)
	return ids


static func footprint(id: StringName) -> Vector2i:
	var entry := get_entry(id)
	return entry.get("footprint", Vector2i(1, 1)) as Vector2i


static func load_texture(id: StringName) -> Texture2D:
	var entry := get_entry(id)
	var path: String = entry.get("texture", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
