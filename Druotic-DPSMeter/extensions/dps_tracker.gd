extends Node

# Rolling DPS tracker that records *actual* damage dealt (no overkill).
# Damage hooks call `record_damage(player_index, actual_dmg)`.

const MOD_NAME: String = "DPSMeter"
const MAX_PLAYERS: int = 4

var _charm_tracker: Node = null

var _window_seconds: float = 5.0
var _enabled: bool = true

var _window_times: Array = []
var _window_amounts: Array = []
var _window_head: Array = []
var _window_sum: Array = []

var _total_actual: Array = []

func _ready() -> void:
	_reset_state()

func set_charm_tracker(charm_tracker: Node) -> void:
	_charm_tracker = charm_tracker

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func set_window_seconds(seconds: float) -> void:
	var new_seconds = max(1.0, float(seconds))
	if abs(new_seconds - _window_seconds) < 0.0001:
		return
	_window_seconds = new_seconds
	_reset_state()

func _reset_state() -> void:
	_window_times.resize(MAX_PLAYERS)
	_window_amounts.resize(MAX_PLAYERS)
	_window_head.resize(MAX_PLAYERS)
	_window_sum.resize(MAX_PLAYERS)
	_total_actual.resize(MAX_PLAYERS)

	for i in range(MAX_PLAYERS):
		_window_times[i] = []
		_window_amounts[i] = []
		_window_head[i] = 0
		_window_sum[i] = 0
		_total_actual[i] = 0

func record_damage(player_index: int, actual_dmg: int) -> void:
	if not _enabled:
		return

	if player_index < 0 or player_index >= RunData.get_player_count():
		return
	if actual_dmg <= 0:
		return

	var now = OS.get_ticks_msec() / 1000.0
	var times: Array = _window_times[player_index]
	var amounts: Array = _window_amounts[player_index]

	times.append(now)
	amounts.append(actual_dmg)
	_window_sum[player_index] += actual_dmg
	_total_actual[player_index] += actual_dmg

func update_charm_state_if_needed(now: float) -> void:
	# Cheap early-out inside charm tracker; call here so overlay stays simple.
	if not is_instance_valid(_charm_tracker):
		return
	_charm_tracker.update_charm_tracking_state()

func _prune_player(player_index: int, now: float) -> void:
	var times: Array = _window_times[player_index]
	var amounts: Array = _window_amounts[player_index]
	var head: int = _window_head[player_index]

	var cutoff = now - _window_seconds
	while head < times.size() and float(times[head]) < cutoff:
		_window_sum[player_index] -= int(amounts[head])
		head += 1

	_window_head[player_index] = head

	# Compact arrays when we've advanced far to avoid unbounded growth.
	if head > 256 and head > times.size() / 2:
		_window_times[player_index] = times.slice(head, times.size())
		_window_amounts[player_index] = amounts.slice(head, amounts.size())
		_window_head[player_index] = 0

func get_stats() -> Dictionary:
	var now = OS.get_ticks_msec() / 1000.0
	update_charm_state_if_needed(now)

	var player_count: int = RunData.get_player_count()
	var players: Array = []

	for i in range(player_count):
		_prune_player(i, now)
		var window_damage: int = int(_window_sum[i])
		var window_dps: float = 0.0
		if _window_seconds > 0:
			window_dps = float(window_damage) / float(_window_seconds)

		players.append({
			"player_index": i,
			"window_damage": window_damage,
			"window_dps": window_dps,
			"total_actual_damage": int(_total_actual[i])
		})

	return {
		"player_count": player_count,
		"window_seconds": _window_seconds,
		"players": players
	}

