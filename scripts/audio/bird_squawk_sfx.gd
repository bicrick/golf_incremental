class_name BirdSquawkSfx
extends RefCounted
## Royalty-free bird flush / scare cues under assets/audio/sfx/birds/.

const BIRDS_SFX_DIR := "res://assets/audio/sfx/birds/"

## Mixkit License + Freesound CC0.
const SQUAWK_FILES: Array[String] = [
	"mixkit-wild-raven-bird-calling-62.wav",
	"mixkit-tropical-bird-squeak-27.wav",
	"freesound-upset-bird-chirp-812036.ogg",
]


static func paths() -> Array[String]:
	var out: Array[String] = []
	for file_name in SQUAWK_FILES:
		out.append(BIRDS_SFX_DIR.path_join(file_name))
	return out
