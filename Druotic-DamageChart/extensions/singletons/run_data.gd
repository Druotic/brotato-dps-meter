extends "res://singletons/run_data.gd"

const MOD_MAIN_PATH = "/root/ModLoader/Druotic-DamageChart"

func reset(restart: bool = false) -> void:
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main:
		if restart:
			mod_main.on_run_reset(restart)
		else:
			mod_main.capture_pending_wave_damage()
	.reset(restart)

func get_state() -> Dictionary:
	var state = .get_state()
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main:
		state["damage_chart"] = mod_main.get_persist_state()
	return state

func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main and state.has("damage_chart"):
		mod_main.apply_persist_state(state["damage_chart"])

func reset_to_start_wave_state() -> void:
	.reset_to_start_wave_state()
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main:
		mod_main.on_retry_wave()
