extends Node

# Lightweight cache to determine whether "charm" attribution is possible this run.

const MOD_NAME: String = "DPSMeter"

var charm_tracking_enabled: bool = false
var last_check_wave: int = -1

func update_charm_tracking_state() -> void:
	var current_wave = RunData.current_wave
	if last_check_wave == current_wave:
		return

	last_check_wave = current_wave
	charm_tracking_enabled = false

	for i in range(RunData.get_player_count()):
		var character = RunData.get_player_character(i)
		if is_instance_valid(character) and character.my_id == "character_romantic":
			charm_tracking_enabled = true
			return

		var weapons = RunData.get_player_weapons(i)
		for weapon in weapons:
			if is_instance_valid(weapon) and weapon.weapon_id == "weapon_flute":
				charm_tracking_enabled = true
				return

		if RunData.players_data.size() > i:
			var player_data = RunData.players_data[i]
			if "effects" in player_data and "charm_on_hit" in player_data.effects:
				if player_data.effects["charm_on_hit"].size() > 0:
					charm_tracking_enabled = true
					return

