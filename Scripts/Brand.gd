extends RefCounted

const PRODUCT_NAME := "Ice Legends '94"
const TAGLINE := "Retro arcade hockey"
const STUDIO := "DIDDLERRR"
const PRIVACY_URL := "https://workinmanstrokes.github.io/test-builds/privacy/nhl94-remake.html"

static func open_privacy() -> void:
	OS.shell_open(PRIVACY_URL)
