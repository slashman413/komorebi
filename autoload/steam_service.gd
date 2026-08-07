extends Node

## SteamService (Autoload singleton) — STUB for Increment 0.
## ------------------------------------------------------------------
## The real thing will wrap GodotSteam (the Steamworks GDExtension) for
## achievements, cloud saves, Steam Input, and the Deck's haptics/gyro. We do NOT
## take that dependency yet — a missing GDExtension would break `--headless`
## import and the CI parse gate. So this stub presents the same surface the game
## will call, backed by no-ops, and reports itself as unavailable.
##
## `available` stays false until GodotSteam is wired in a later increment.

signal overlay_toggled(active: bool)

var available: bool = false ## True once GodotSteam initializes successfully.
var app_id: int = 0
var is_on_steam_deck: bool = false

func _ready() -> void:
	# Detect the Deck without the Steam SDK: SteamOS sets this env var. This lets
	# the spike tune defaults for the Deck even before GodotSteam is present.
	is_on_steam_deck = OS.has_environment("SteamDeck") or OS.get_name() == "Linux" and OS.has_environment("SteamOS")
	if not available:
		print("[SteamService] stub active (GodotSteam not linked). deck=%s" % is_on_steam_deck)

## No-op until GodotSteam is linked. Returns false so callers can branch.
func unlock_achievement(_api_name: String) -> bool:
	if not available:
		return false
	return false

## Placeholder for Steam Cloud. Increment 0 persists locally via SaveService only.
func is_cloud_enabled() -> bool:
	return false
