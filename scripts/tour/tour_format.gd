class_name TourFormat
extends RefCounted
## Short number formatting for a 480×270 screen.

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi"]


static func money(v: float) -> String:
	if v < 10.0:
		return "%.2f" % v
	if v < 1000.0:
		return "%d" % int(floor(v))
	var tier := 0
	var x := v
	while x >= 1000.0 and tier < SUFFIXES.size() - 1:
		x /= 1000.0
		tier += 1
	if x < 10.0:
		return "%.2f%s" % [x, SUFFIXES[tier]]
	if x < 100.0:
		return "%.1f%s" % [x, SUFFIXES[tier]]
	return "%d%s" % [int(x), SUFFIXES[tier]]


static func mult(v: float) -> String:
	if absf(v - roundf(v)) < 0.01:
		return "%d" % int(roundf(v))
	return "%.1f" % v


static func yards(v: float) -> String:
	return "%d" % int(roundf(v))
