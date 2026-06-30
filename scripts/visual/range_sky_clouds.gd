extends Node2D
## Small procedural day clouds for the range sky — fade with day/night cycle.

const PIXEL := 2.0
const CLOUD_BODY := Color(0.94, 0.97, 1.0, 0.92)
const CLOUD_SHADE := Color(0.78, 0.84, 0.92, 0.85)
const BOB_FREQ := 0.06

var _base_alpha := 0.0
var _bob_time := 0.0

const _CLOUDS: Array[Dictionary] = [
	{"base": Vector2(72.0, 34.0), "cells": [[0, 0], [1, 0], [2, 0], [1, -1], [0, -1]], "phase": 0.0},
	{"base": Vector2(210.0, 22.0), "cells": [[0, 0], [1, 0], [2, 0], [3, 0], [1, -1], [2, -1]], "phase": 1.7},
	{"base": Vector2(360.0, 40.0), "cells": [[0, 0], [1, 0], [0, -1], [1, -1], [2, -1]], "phase": 3.1},
]


func _ready() -> void:
	modulate.a = 0.0
	set_process(true)


func apply_visibility(cycle_alpha: float) -> void:
	_base_alpha = clampf(cycle_alpha, 0.0, 1.0)
	modulate.a = _base_alpha


func _process(delta: float) -> void:
	if _base_alpha <= 0.001:
		if modulate.a > 0.001:
			modulate.a = 0.0
		return
	_bob_time += delta
	modulate.a = _base_alpha
	queue_redraw()


func _draw() -> void:
	if modulate.a <= 0.001:
		return
	for cloud in _CLOUDS:
		var bob_x := sin(_bob_time * BOB_FREQ * TAU + float(cloud["phase"])) * 2.5
		var bob_y := sin(_bob_time * BOB_FREQ * TAU * 0.7 + float(cloud["phase"]) + 0.8) * 1.0
		var origin: Vector2 = cloud["base"] + Vector2(bob_x, bob_y)
		for cell in cloud["cells"]:
			var px := int(cell[0])
			var py := int(cell[1])
			var rect := Rect2(
				origin + Vector2(float(px), float(py)) * PIXEL * 3.0,
				Vector2(PIXEL * 3.0, PIXEL * 3.0)
			)
			var is_shade := px == 0 and py >= 0
			draw_rect(rect, CLOUD_SHADE if is_shade else CLOUD_BODY)
