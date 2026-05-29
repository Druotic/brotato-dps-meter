extends Node

const MOD_ID = "Druotic-DamageChart"
const DISPLAY_NAME = "Damage Chart"
const MOD_OPTIONS_ID = "DamageChart"
const OVERLAY_SCRIPT_PATH = "res://mods-unpacked/Druotic-DamageChart/ui/hud/direct_meter_overlay.gd"
const RUN_DAMAGE_DIR = "user://damage_chart"
const RUN_DAMAGE_FILE = "user://damage_chart/run_damage.json"
const MIN_DPS_SECONDS = 5.0
const MAX_PLAYERS = 4

var _overlay_layer = null
var _total_damage = [0, 0, 0, 0]
var _max_dps = [0.0, 0.0, 0.0, 0.0]
var _run_total_damage = [0, 0, 0, 0]
var _committed_waves = []
var _committed_wave_numbers = {}
var _run_id = ""
var _last_wave = -1
var _has_seen_active_wave = false
var _wave_started_at = 0.0
var _wave_active = false
var _wave_committed = false
var _last_committed_wave = -1
var _hide_solo = false
var _run_overlay_visible = false
var _mod_options_attempts = 0
var _pending_wave_damage = [0, 0, 0, 0]
var _pending_wave_number = -1
var _was_combat_wave_active = false

func _init() -> void:
	ModLoaderLog.info("Init", MOD_ID)
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DamageChart/extensions/enemy_extension.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DamageChart/extensions/neutral_extension.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DamageChart/extensions/singletons/run_data.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DamageChart/extensions/ui/menus/run/base_end_run.gd")

func _ready() -> void:
	_ensure_persist_dir()
	call_deferred("_inject_overlay")
	call_deferred("_register_mod_options")

func _process(_delta) -> void:
	if typeof(RunData) != TYPE_NIL:
		_maybe_commit_completed_wave()
		_maybe_reset_for_wave()
		_maybe_update_pending_snapshot()

func record_damage(player_index, _raw_dmg, actual_dmg, _attributed_by_charm = false) -> void:
	if typeof(RunData) != TYPE_NIL:
		_maybe_reset_for_wave()

	if player_index < 0 or player_index >= _total_damage.size():
		return

	var counted_dmg = int(actual_dmg)
	if counted_dmg <= 0:
		return

	_total_damage[player_index] += counted_dmg
	capture_pending_wave_damage()

	var current_dps = _get_average_dps(player_index)
	if current_dps > _max_dps[player_index]:
		_max_dps[player_index] = current_dps

func set_run_overlay_visible(visible: bool) -> void:
	_run_overlay_visible = visible

func prepare_end_run_display() -> void:
	capture_pending_wave_damage()

func capture_pending_wave_damage() -> void:
	if typeof(RunData) == TYPE_NIL:
		return

	var wave_number = int(RunData.current_wave)
	if wave_number <= 0 or _committed_wave_numbers.has(wave_number):
		_clear_pending_wave_damage()
		return

	_pending_wave_number = wave_number
	_pending_wave_damage = _total_damage.duplicate()

func is_solo_hidden() -> bool:
	if not _hide_solo:
		return false
	if typeof(RunData) == TYPE_NIL:
		return false
	return RunData.get_player_count() <= 1

func on_retry_wave() -> void:
	_run_overlay_visible = false
	_clear_pending_wave_damage()
	_reset_damage()
	_wave_committed = false
	_wave_active = false
	_was_combat_wave_active = false

func get_meter_stats() -> Dictionary:
	var use_run_totals = _run_overlay_visible
	var totals = _run_total_damage.duplicate() if use_run_totals else _total_damage.duplicate()

	if use_run_totals and typeof(RunData) != TYPE_NIL:
		var wave_number = int(RunData.current_wave)
		if wave_number > 0 and not _committed_wave_numbers.has(wave_number):
			var pending = _get_uncommitted_wave_damage(wave_number)
			for i in range(totals.size()):
				totals[i] += int(pending[i])
	var current_dps = []
	var max_dps = []

	for i in range(_total_damage.size()):
		if use_run_totals:
			current_dps.append(0.0)
			max_dps.append(0.0)
		else:
			current_dps.append(_get_average_dps(i))
			max_dps.append(_max_dps[i])

	var player_count = 0
	if typeof(RunData) != TYPE_NIL:
		player_count = RunData.get_player_count()

	return {
		"player_count": player_count,
		"show_overlay": _should_show_overlay(),
		"use_run_totals": use_run_totals,
		"total_damage": totals,
		"current_dps": current_dps,
		"max_dps": max_dps,
		"hide_solo": _hide_solo,
		"display_name": DISPLAY_NAME
	}

func get_run_stats() -> Dictionary:
	var player_count = 0
	if typeof(RunData) != TYPE_NIL:
		player_count = RunData.get_player_count()

	return {
		"player_count": player_count,
		"completed_waves": _committed_waves.size(),
		"run_total_damage": _run_total_damage.duplicate(),
		"waves": _committed_waves.duplicate(),
		"run_id": _run_id
	}

func get_persist_state() -> Dictionary:
	return {
		"run_id": _run_id,
		"run_total_damage": _run_total_damage.duplicate(),
		"committed_waves": _committed_waves.duplicate(),
		"committed_wave_numbers": _committed_wave_numbers.duplicate()
	}

func apply_persist_state(state: Dictionary) -> void:
	if not state is Dictionary:
		return

	_run_id = str(state.get("run_id", ""))
	_run_total_damage = _normalize_damage_array(state.get("run_total_damage", []))
	_committed_waves = state.get("committed_waves", []).duplicate()
	_committed_wave_numbers = state.get("committed_wave_numbers", {}).duplicate()
	_merge_from_disk_json_if_needed()
	_save_run_damage_json()

func on_run_reset(_restart: bool = false) -> void:
	_run_overlay_visible = false
	_run_id = _generate_run_id()
	_run_total_damage = _create_damage_array()
	_committed_waves = []
	_committed_wave_numbers = {}
	_clear_pending_wave_damage()
	_reset_wave_tracking()
	_delete_run_damage_json()
	_was_combat_wave_active = false

func _should_show_overlay() -> bool:
	if _run_overlay_visible:
		return true
	return _is_combat_wave_active()

func _is_combat_wave_active() -> bool:
	if typeof(RunData) == TYPE_NIL or not RunData.wave_in_progress:
		return false

	var wave_timer = _get_wave_timer()
	if not is_instance_valid(wave_timer):
		return false

	return float(wave_timer.time_left) > 0.0

func _maybe_update_pending_snapshot() -> void:
	var combat_active = _is_combat_wave_active()
	if _was_combat_wave_active and not combat_active:
		capture_pending_wave_damage()
	_was_combat_wave_active = combat_active

func _get_uncommitted_wave_damage(wave_number: int) -> Array:
	if wave_number <= 0 or _committed_wave_numbers.has(wave_number):
		return _create_damage_array()
	if _pending_wave_number == wave_number:
		return _pending_wave_damage.duplicate()
	return _total_damage.duplicate()

func _clear_pending_wave_damage() -> void:
	_pending_wave_damage = _create_damage_array()
	_pending_wave_number = -1

func _maybe_reset_for_wave() -> void:
	var current_wave = int(RunData.current_wave)
	var wave_in_progress = RunData.wave_in_progress

	if not wave_in_progress:
		return

	if not _has_seen_active_wave or current_wave != _last_wave:
		_reset_damage()

	_has_seen_active_wave = true
	_last_wave = current_wave

func _maybe_commit_completed_wave() -> void:
	var wave_timer = _get_wave_timer()
	if not is_instance_valid(wave_timer):
		return

	if float(wave_timer.time_left) > 0.0:
		if RunData.wave_in_progress:
			_wave_active = true
			_wave_committed = false
		return

	if not _wave_active or _wave_committed:
		return

	_commit_completed_wave(int(RunData.current_wave))
	_wave_committed = true
	_wave_active = false

func _commit_completed_wave(wave_number: int) -> void:
	if wave_number <= 0:
		return
	if _committed_wave_numbers.has(wave_number):
		return
	if _run_id == "":
		_run_id = _generate_run_id()

	var wave_damage = _total_damage.duplicate()

	_committed_wave_numbers[wave_number] = true
	_committed_waves.append({
		"wave": wave_number,
		"damage": wave_damage
	})

	for i in range(_run_total_damage.size()):
		_run_total_damage[i] += int(wave_damage[i])

	_last_committed_wave = wave_number
	_clear_pending_wave_damage()
	_save_run_damage_json()

func _reset_damage() -> void:
	for i in range(_total_damage.size()):
		_total_damage[i] = 0
		_max_dps[i] = 0.0
	_wave_started_at = OS.get_ticks_msec() / 1000.0
	_wave_committed = false

func _reset_wave_tracking() -> void:
	_total_damage = _create_damage_array()
	_max_dps = [0.0, 0.0, 0.0, 0.0]
	_last_wave = -1
	_has_seen_active_wave = false
	_wave_started_at = 0.0
	_wave_active = false
	_wave_committed = false
	_last_committed_wave = -1

func _get_average_dps(player_index) -> float:
	if player_index < 0 or player_index >= _total_damage.size():
		return 0.0

	var elapsed = _get_wave_elapsed_seconds()
	var denominator = max(elapsed, MIN_DPS_SECONDS)
	return float(_total_damage[player_index]) / denominator

func _get_wave_elapsed_seconds() -> float:
	var wave_timer = _get_wave_timer()
	if is_instance_valid(wave_timer) and "wait_time" in wave_timer and "time_left" in wave_timer:
		return max(0.0, float(wave_timer.wait_time) - float(wave_timer.time_left))

	if _wave_started_at <= 0.0:
		return 0.0
	return max(0.0, OS.get_ticks_msec() / 1000.0 - _wave_started_at)

func _get_wave_timer():
	var main = get_tree().get_current_scene()
	if not is_instance_valid(main):
		return null
	return main.get_node_or_null("WaveTimer")

func _ensure_persist_dir() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(RUN_DAMAGE_DIR):
		dir.make_dir(RUN_DAMAGE_DIR)

func _merge_from_disk_json_if_needed() -> void:
	var disk = _load_run_damage_json()
	if not disk is Dictionary:
		return
	if _run_id == "":
		_run_id = str(disk.get("run_id", ""))
	elif str(disk.get("run_id", "")) != _run_id:
		return

	var disk_waves = disk.get("waves", [])
	if not (disk_waves is Array):
		return

	for wave_data in disk_waves:
		if not (wave_data is Dictionary):
			continue
		var wave_number = int(wave_data.get("wave", -1))
		if wave_number <= 0 or _committed_wave_numbers.has(wave_number):
			continue

		var wave_damage = _normalize_damage_array(wave_data.get("damage", []))
		_committed_wave_numbers[wave_number] = true
		_committed_waves.append({
			"wave": wave_number,
			"damage": wave_damage
		})
		for i in range(_run_total_damage.size()):
			_run_total_damage[i] += int(wave_damage[i])

	_committed_waves.sort_custom(self, "_sort_wave_entries")

func _save_run_damage_json() -> void:
	if _run_id == "":
		return

	_ensure_persist_dir()
	var payload = {
		"run_id": _run_id,
		"completed_waves": _committed_waves.size(),
		"player_count": RunData.get_player_count() if typeof(RunData) != TYPE_NIL else 0,
		"run_total_damage": _run_total_damage.duplicate(),
		"waves": _committed_waves.duplicate()
	}

	var file = File.new()
	var error = file.open(RUN_DAMAGE_FILE, File.WRITE)
	if error != OK:
		ModLoaderLog.error("Failed to write run damage JSON: %s" % error, MOD_ID)
		return
	file.store_string(JSON.print(payload, "\t"))
	file.close()

func _load_run_damage_json() -> Dictionary:
	var file = File.new()
	if file.open(RUN_DAMAGE_FILE, File.READ) != OK:
		return {}

	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK:
		return {}
	if not (parsed.result is Dictionary):
		return {}
	return parsed.result

func _delete_run_damage_json() -> void:
	var dir = Directory.new()
	if dir.file_exists(RUN_DAMAGE_FILE):
		dir.remove(RUN_DAMAGE_FILE)

func _generate_run_id() -> String:
	return "%s_%s" % [str(OS.get_unix_time()), str(randi())]

func _create_damage_array() -> Array:
	return [0, 0, 0, 0]

func _normalize_damage_array(values) -> Array:
	var result = _create_damage_array()
	if not (values is Array):
		return result
	for i in range(min(values.size(), MAX_PLAYERS)):
		result[i] = int(values[i])
	return result

func _sort_wave_entries(a, b) -> bool:
	return int(a.get("wave", 0)) < int(b.get("wave", 0))

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
