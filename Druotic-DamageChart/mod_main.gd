extends Node

const MOD_ID = "Druotic-DamageChart"
const DISPLAY_NAME = "Damage Chart"
const MOD_OPTIONS_ID = "DamageChart"
const OVERLAY_SCRIPT_PATH = "res://mods-unpacked/Druotic-DamageChart/ui/hud/direct_meter_overlay.gd"
const MIN_DPS_SECONDS = 5.0

var _overlay_layer = null
var _total_damage = [0, 0, 0, 0]
var _max_dps = [0.0, 0.0, 0.0, 0.0]
var _last_wave = -1
var _has_seen_active_wave = false
var _wave_started_at = 0.0
var _hide_solo = false
var _mod_options_attempts = 0

func _init() -> void:
	ModLoaderLog.info("Init", MOD_ID)
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DamageChart/extensions/enemy_extension.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DamageChart/extensions/neutral_extension.gd")

func _ready() -> void:
	call_deferred("_inject_overlay")
	call_deferred("_register_mod_options")

func _process(_delta) -> void:
	if typeof(RunData) != TYPE_NIL:
		_maybe_reset_for_wave()

func record_damage(player_index, _raw_dmg, actual_dmg, _attributed_by_charm = false) -> void:
	if typeof(RunData) != TYPE_NIL:
		_maybe_reset_for_wave()

	if player_index < 0 or player_index >= _total_damage.size():
		return

	var counted_dmg = int(actual_dmg)
	if counted_dmg <= 0:
		return

	_total_damage[player_index] += counted_dmg

	var current_dps = _get_average_dps(player_index)
	if current_dps > _max_dps[player_index]:
		_max_dps[player_index] = current_dps

func get_meter_stats() -> Dictionary:
	var current_dps = []
	for i in range(_total_damage.size()):
		current_dps.append(_get_average_dps(i))

	var player_count = 0
	var wave_in_progress = false
	if typeof(RunData) != TYPE_NIL:
		player_count = RunData.get_player_count()
		wave_in_progress = RunData.wave_in_progress

	return {
		"player_count": player_count,
		"wave_in_progress": wave_in_progress,
		"total_damage": _total_damage.duplicate(),
		"current_dps": current_dps,
		"max_dps": _max_dps.duplicate(),
		"hide_solo": _hide_solo,
		"display_name": DISPLAY_NAME
	}

func _maybe_reset_for_wave() -> void:
	var current_wave = int(RunData.current_wave)
	var wave_in_progress = RunData.wave_in_progress

	if not wave_in_progress:
		return

	if not _has_seen_active_wave or current_wave != _last_wave:
		_reset_damage()

	_has_seen_active_wave = true
	_last_wave = current_wave

func _reset_damage() -> void:
	for i in range(_total_damage.size()):
		_total_damage[i] = 0
		_max_dps[i] = 0.0
	_wave_started_at = OS.get_ticks_msec() / 1000.0

func _get_average_dps(player_index) -> float:
	if player_index < 0 or player_index >= _total_damage.size():
		return 0.0

	var elapsed = _get_wave_elapsed_seconds()
	var denominator = max(elapsed, MIN_DPS_SECONDS)
	return float(_total_damage[player_index]) / denominator

func _get_wave_elapsed_seconds() -> float:
	var main = get_tree().get_current_scene()
	if is_instance_valid(main):
		var wave_timer = main.get_node_or_null("WaveTimer")
		if is_instance_valid(wave_timer) and "wait_time" in wave_timer and "time_left" in wave_timer:
			return max(0.0, float(wave_timer.wait_time) - float(wave_timer.time_left))

	if _wave_started_at <= 0.0:
		return 0.0
	return max(0.0, OS.get_ticks_msec() / 1000.0 - _wave_started_at)

func _inject_overlay() -> void:
	if is_instance_valid(_overlay_layer):
		return

	var root = get_tree().get_root()
	if not root:
		return

	var overlay_script = load(OVERLAY_SCRIPT_PATH)
	if overlay_script == null:
		ModLoaderLog.error("Overlay script failed to load", MOD_ID)
		return

	var overlay = overlay_script.new()
	overlay.name = "DruoticDamageChartOverlay"
	overlay.set_meter(self)

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	_overlay_layer.add_child(overlay)
	root.add_child(_overlay_layer)
	ModLoaderLog.info("Meter overlay injected", MOD_ID)

func _register_mod_options() -> void:
	var mod_options = _get_mod_options()
	if not is_instance_valid(mod_options):
		_mod_options_attempts += 1
		if _mod_options_attempts < 60:
			call_deferred("_register_mod_options")
		else:
			ModLoaderLog.debug("ModOptions not found; using default damage mode", MOD_ID)
		return

	mod_options.register_mod_options(MOD_OPTIONS_ID, {
		"tab_title": DISPLAY_NAME,
		"options": [
			{
				"type": "toggle",
				"id": "hide_solo",
				"label": "Hide Damage Chart (Solo)",
				"default": false,
				"help_text": "Hide the chart when only one player is active."
			}
		],
		"info_text": "Damage Chart always counts actual HP removed, excluding overkill."
	})

	_apply_mod_options()
	if not mod_options.is_connected("config_changed", self, "_on_mod_options_changed"):
		mod_options.connect("config_changed", self, "_on_mod_options_changed")

func _on_mod_options_changed(mod_id, option_id, _new_value) -> void:
	if mod_id != MOD_OPTIONS_ID:
		return
	if option_id == "hide_solo":
		_apply_mod_options()

func _apply_mod_options() -> void:
	var mod_options = _get_mod_options()
	if not is_instance_valid(mod_options):
		return

	_hide_solo = mod_options.get_value(MOD_OPTIONS_ID, "hide_solo") == true

func _get_mod_options():
	var root = get_tree().get_root()
	if not root:
		return null

	var mod_loader = root.get_node_or_null("ModLoader")
	if not mod_loader:
		return null

	var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null

	return mod_options_mod.get_node_or_null("ModOptions")

