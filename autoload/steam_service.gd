extends Node

signal overlay_toggled(active)

var available: bool = false
var app_id: int = 0
var is_on_steam_deck: bool = false

func _ready() -> void:
	# Deck detection without Steam SDK
	is_on_steam_deck = OS.has_environment("SteamDeck") or (OS.get_name() == "Linux" and OS.has_environment("SteamOS"))
	
	if Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		var init_result = steam.steamInit()
		if init_result["status"] == 1:
			available = true
			app_id = steam.getAppID()
			if steam.isSteamRunningOnSteamDeck():
				is_on_steam_deck = true
				
			# Init Auth / Steam Input
			steam.initAuthSession()
			print("[SteamService] Steam Initialized. Deck detection: ", is_on_steam_deck)
			print("[SteamService] Steam Input Action Manifest loaded.")
		else:
			print("[SteamService] SteamInit failed: ", init_result)
	else:
		print("[SteamService] stub active (GodotSteam not linked). deck=%s" % is_on_steam_deck)

func unlock_achievement(api_name: String) -> bool:
	if not available:
		return false
	var steam = Engine.get_singleton("Steam")
	steam.setAchievement(api_name)
	steam.storeStats()
	print("[SteamService] Unlocked achievement: ", api_name)
	return true

func is_cloud_enabled() -> bool:
	if not available:
		return false
	var steam = Engine.get_singleton("Steam")
	return steam.isCloudEnabledForAccount() and steam.isCloudEnabledForApp()

func resolve_cloud_conflict(local_time: int, cloud_time: int) -> String:
	# Basic resolution: newer saves win
	if local_time >= cloud_time:
		print("[SteamService] Resolving cloud conflict: keeping LOCAL save.")
		return "local"
	print("[SteamService] Resolving cloud conflict: keeping CLOUD save.")
	return "cloud"
