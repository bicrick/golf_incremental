class_name TourLooks
extends RefCounted
## v8 — how each range looks: ground palette, haze, mist, weather, backdrop.
## Keyed by range id. Colors are hex so they read like a palette sheet.

const LOOKS := {
	"barley": {
		"style": 0,
		"fairway_a": "5fa83c", "fairway_b": "529a35",
		"rough_a": "3f7f2c", "rough_b": "377227",
		"outer_a": "2f6a2a", "outer_b": "285d25",
		"green_a": "74c24a", "green_b": "68b443", "fringe": "4b8e34",
		"hazard_a": "2d6f9e", "hazard_b": "4a90bd",
		"accent": "fff1b0",
		"haze": "f3cfb3", "haze_start": 110.0, "haze_end": 520.0, "haze_max": 0.7,
		"mist": 0.75, "mist_color": "fbe9e0", "mist_far": 0.6,
		"darkness": 0.0,
		"sky": "f6c7a8",
		"props": [["barley_pine", 4, 0.28], ["barley_oak", 3, 0.26], ["barley_bush", 4, 0.2], ["barley_hay", 1, 0.2]],
		"weather": "pollen",
		"stripe": 10.0,
	},
	"cliffs": {
		"style": 1,
		"fairway_a": "6cb546", "fairway_b": "5fa63e",
		"rough_a": "8a9d58", "rough_b": "7c8f4f",
		"outer_a": "b9b07a", "outer_b": "a89f6b",
		"green_a": "7fcc50", "green_b": "72bd49", "fringe": "56983a",
		"hazard_a": "1f6d9a", "hazard_b": "3a8fbd",
		"accent": "f2fbff",
		"haze": "cfe6f2", "haze_start": 90.0, "haze_end": 360.0, "haze_max": 0.7,
		"mist": 0.0, "mist_color": "ffffff", "mist_far": 1.0,
		"darkness": 0.0,
		"sky": "9fd3ee",
		"props": [["cliffs_rock", 2, 0.26], ["cliffs_grass", 3, 0.2], ["cliffs_gorse", 5, 0.24]],
		"weather": "spray",
		"sea_side": 58.0,
		"stripe": 12.0,
	},
	"mesa": {
		"style": 2,
		"fairway_a": "8ea447", "fairway_b": "7f953f",
		"rough_a": "b8844d", "rough_b": "a97745",
		"outer_a": "c26f40", "outer_b": "b3633a",
		"green_a": "94b650", "green_b": "86a749", "fringe": "6d8a3a",
		"hazard_a": "5a2a24", "hazard_b": "8a3f2c",
		"accent": "ffd9a0",
		"haze": "f2a071", "haze_start": 120.0, "haze_end": 480.0, "haze_max": 0.75,
		"mist": 0.0, "mist_color": "ffd2a8", "mist_far": 1.0,
		"darkness": 0.0,
		"sky": "f0906a",
		"props": [["mesa_saguaro", 4, 0.3], ["mesa_rock", 3, 0.3], ["mesa_scrub", 4, 0.22]],
		"weather": "dust",
		"stripe": 14.0,
	},
	"frost": {
		"style": 3,
		"fairway_a": "dfe9f2", "fairway_b": "d2dfeb",
		"rough_a": "c3d3e3", "rough_b": "b7c8da",
		"outer_a": "e8f0f7", "outer_b": "d9e5ef",
		"green_a": "9fc0a4", "green_b": "93b69a", "fringe": "b5cdbc",
		"hazard_a": "3a5070", "hazard_b": "4a6488",
		"accent": "ffffff",
		"haze": "24305a", "haze_start": 120.0, "haze_end": 520.0, "haze_max": 0.85,
		"mist": 0.0, "mist_color": "a8b8e0", "mist_far": 1.0,
		"darkness": 1.0,
		"sky": "1a2248",
		"props": [["frost_pine", 6, 0.3], ["frost_drift", 3, 0.3], ["frost_rock", 2, 0.24]],
		"weather": "snow",
		"stripe": 14.0,
	},
	"edge": {
		"style": 4,
		"fairway_a": "6e9a64", "fairway_b": "628d5b",
		"rough_a": "56785a", "rough_b": "4c6c52",
		"outer_a": "f3d7e4", "outer_b": "e6c3d9",
		"green_a": "86b077", "green_b": "7aa36d", "fringe": "5e8456",
		"hazard_a": "3a5070", "hazard_b": "4a6488",
		"accent": "fff6e0",
		"haze": "f7c9a8", "haze_start": 160.0, "haze_end": 700.0, "haze_max": 0.8,
		"mist": 1.0, "mist_color": "fff0f4", "mist_far": 0.2,
		"darkness": 0.0,
		"sky": "d9a6c8",
		"props": [["edge_cloud", 3, 0.5], ["edge_cloud_s", 4, 0.4]],
		"weather": "motes",
		"stripe": 16.0,
	},
}


static func look(range_id: String) -> Dictionary:
	return LOOKS.get(range_id, LOOKS["barley"])


static func c(hex: String) -> Color:
	return Color.html(hex)
