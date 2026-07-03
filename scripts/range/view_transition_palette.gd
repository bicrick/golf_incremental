class_name ViewTransitionPalette
extends RefCounted
## Day/night-aware wash colors for strike/harvest view crossfades.


static func wash_for_mode(target: ViewModeController.Mode, cycle_time: float) -> Color:
	var snap := DayNightPalette.sample_at(cycle_time)
	var day_factor := DayNightPalette.celestial_alpha(cycle_time, false)
	var stripe_colors := DayNightPalette.fairway_stripe_colors(snap, day_factor)
	var fairway := stripe_colors[0].lerp(stripe_colors[1], 0.45)
	var sky := snap.sky

	var green_bias := lerpf(0.80, 0.50, 1.0 - day_factor)
	var sky_bias := lerpf(0.65, 0.88, 1.0 - day_factor)

	if target == ViewModeController.Mode.HARVEST:
		return sky.lerp(fairway, green_bias)
	return fairway.lerp(sky, sky_bias)


static func luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
