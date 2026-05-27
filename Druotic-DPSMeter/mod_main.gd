extends Node

const MOD_ID = "Druotic-DPSMeter"
const OVERLAY_SCRIPT_PATH = "res://mods-unpacked/Druotic-DPSMeter/ui/hud/direct_meter_overlay.gd"

var _overlay_layer = null
var _total_damage = [0, 0, 0, 0]
var _window_damage = [0, 0, 0, 0]
var _max_dps = [0.0, 0.0, 0.0, 0.0]
var _event_times = [[], [], [], []]
var _event_amounts = [[], [], [], []]
var _last_wave = -1
var _has_seen_active_wave = false
var _window_seconds = 5.0

func _init() -> void:
	ModLoaderLog.info("Init", MOD_ID)
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DPSMeter/extensions/enemy_extension.gd")
	ModLoaderMod.install_script_extension("res://mods-unpacked/Druotic-DPSMeter/extensions/neutral_extension.gd")

func _ready() -> void:
	call_deferred("_inject_overlay")

func _process(_delta) -> void:
	if typeof(RunData) != TYPE_NIL:
		_maybe_reset_for_wave()
		_prune_window()

func record_damage(player_index, actual_dmg) -> void:
	if typeof(RunData) != TYPE_NIL:
		_maybe_reset_for_wave()
		_prune_window()

	if player_index < 0 or player_index >= _total_damage.size():
		return
	if actual_dmg <= 0:
		return
	_total_damage[player_index] += int(actual_dmg)
	_window_damage[player_index] += int(actual_dmg)
	_event_times[player_index].append(OS.get_ticks_msec() / 1000.0)
	_event_amounts[player_index].append(int(actual_dmg))

	var current_dps = float(_window_damage[player_index]) / _window_seconds
	if current_dps > _max_dps[player_index]:
		_max_dps[player_index] = current_dps

func get_meter_stats() -> Dictionary:
	_prune_window()
	var current_dps = []
	for i in range(_total_damage.size()):
		current_dps.append(float(_window_damage[i]) / _window_seconds)

	var player_count = 0
	if typeof(RunData) != TYPE_NIL:
		player_count = RunData.get_player_count()

	return {
		"player_count": player_count,
		"total_damage": _total_damage.duplicate(),
		"current_dps": current_dps,
		"max_dps": _max_dps.duplicate(),
		"window_seconds": _window_seconds
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
		_window_damage[i] = 0
		_max_dps[i] = 0.0
		_event_times[i] = []
		_event_amounts[i] = []

func _prune_window() -> void:
	var cutoff = OS.get_ticks_msec() / 1000.0 - _window_seconds
	for player_index in range(_event_times.size()):
		while _event_times[player_index].size() > 0 and float(_event_times[player_index][0]) < cutoff:
			_window_damage[player_index] -= int(_event_amounts[player_index][0])
			_event_times[player_index].pop_front()
			_event_amounts[player_index].pop_front()

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
	overlay.name = "DruoticDpsMeterOverlay"
	overlay.set_meter(self)

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	_overlay_layer.add_child(overlay)
	root.add_child(_overlay_layer)
	ModLoaderLog.info("Meter overlay injected", MOD_ID)

