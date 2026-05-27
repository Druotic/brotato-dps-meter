extends Control

# HUD overlay for accurate real-time DPS.

const MOD_DIR_NAME = "Druotic-DPSMeter"
const TRACKER_NODE_NAME = "DpsMeterTracker"

const MAX_PLAYERS = 4
const REFRESH_INTERVAL_SEC = 0.1

var _tracker = null
var _tracker_loaded = false

# UI nodes (cached in _ready).
var _pie: Control = null
var _damage_labels: Array = []
var _dps_labels: Array = []

# Config (optional via ModOptions)
var _enabled: bool = true
var _opacity: float = 1.0
var _window_seconds: float = 5.0
var _show_damage: bool = true
var _show_dps: bool = true

var _accum: float = 0.0
var _last_applied_window_seconds: float = -1.0

# Player colors (fallback). These are intentionally distinct and readable.
var _player_colors = [
	Color(0.20, 0.78, 0.60, 1.0), # P1
	Color(0.95, 0.70, 0.15, 1.0), # P2
	Color(0.65, 0.25, 0.95, 1.0), # P3
	Color(0.35, 0.55, 0.98, 1.0)  # P4
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bottom_strip_layout()
	_cache_nodes()
	_load_config()
	_connect_modoptions_if_available()
	_apply_config(true)
	_refresh()

func _notification(what: int) -> void:
	# Keep the overlay pinned to the bottom strip when window size changes.
	if what == NOTIFICATION_RESIZED:
		_apply_bottom_strip_layout()

func _apply_bottom_strip_layout() -> void:
	# TEMP: bottom-left so we can tell this apart from Slippy's overlay.
	var width = 280.0
	var height = 120.0
	var pad = 12.0

	anchor_left = 0
	anchor_right = 0
	anchor_top = 1
	anchor_bottom = 1
	margin_left = pad
	margin_right = pad + width
	margin_top = pad - height
	margin_bottom = pad

func _cache_nodes() -> void:
	_pie = get_node_or_null("MainHBox/PieChart")

	_damage_labels.resize(MAX_PLAYERS)
	_dps_labels.resize(MAX_PLAYERS)

	for i in range(MAX_PLAYERS):
		var p = i + 1
		var row_name = "PlayerRowP%d" % p
		var dmg_path = "MainHBox/RightVBox/%s/PlayerDamageLabelP%d" % [row_name, p]
		var dps_path = "MainHBox/RightVBox/%s/PlayerDpsLabelP%d" % [row_name, p]
		_damage_labels[i] = get_node_or_null(dmg_path)
		_dps_labels[i] = get_node_or_null(dps_path)

func _process(delta: float) -> void:
	if not _enabled:
		return

	_accum += delta
	if _accum < REFRESH_INTERVAL_SEC:
		return
	_accum = 0.0
	_refresh()

func _lazy_load_tracker() -> void:
	if _tracker_loaded:
		return
	_tracker = get_node_or_null("/root/ModLoader/%s/%s" % [MOD_DIR_NAME, TRACKER_NODE_NAME])
	_tracker_loaded = true

func _refresh_config_from_modoptions() -> void:
	# Best-effort: if ModOptions isn't installed, keep defaults.
	var mod_options = _get_mod_options()
	if not is_instance_valid(mod_options):
		return

	var v_opacity = mod_options.get_value("DPSMeter", "opacity")
	if v_opacity != null:
		_opacity = float(v_opacity)

	var v_window = mod_options.get_value("DPSMeter", "window_seconds")
	if v_window != null:
		_window_seconds = float(v_window)

	var v_damage = mod_options.get_value("DPSMeter", "show_damage")
	if v_damage != null:
		_show_damage = bool(v_damage)

	var v_dps = mod_options.get_value("DPSMeter", "show_dps")
	if v_dps != null:
		_show_dps = bool(v_dps)

	var v_enabled = mod_options.get_value("DPSMeter", "enabled")
	if v_enabled != null:
		_enabled = bool(v_enabled)

func _load_config() -> void:
	# Initial load. If ModOptions isn't present, defaults remain.
	_refresh_config_from_modoptions()

func _connect_modoptions_if_available() -> void:
	var mod_options = _get_mod_options()
	if not is_instance_valid(mod_options):
		return

	if not mod_options.is_connected("config_changed", self, "_on_config_changed"):
		mod_options.connect("config_changed", self, "_on_config_changed")

func _on_config_changed(_mod_id: String, _option_id: String, _new_value) -> void:
	_refresh_config_from_modoptions()
	_apply_config(false)

func _apply_config(force: bool) -> void:
	visible = _enabled
	modulate.a = _opacity

	_lazy_load_tracker()
	if is_instance_valid(_tracker):
		var window_changed = force or abs(_window_seconds - _last_applied_window_seconds) >= 0.001
		if window_changed:
			_tracker.set_window_seconds(_window_seconds)
			_last_applied_window_seconds = _window_seconds
		_tracker.set_enabled(_enabled)
	else:
		# Defer until tracker exists.
		_last_applied_window_seconds = _window_seconds

func _refresh() -> void:
	if not _enabled:
		return

	_lazy_load_tracker()
	if not is_instance_valid(_tracker):
		return

	var stats = _tracker.get_stats()
	var player_count: int = int(stats.player_count)
	var players: Array = stats.players

	var values = []
	var colors = []
	values.resize(MAX_PLAYERS)
	colors.resize(MAX_PLAYERS)

	for i in range(MAX_PLAYERS):
		values[i] = 0
		colors[i] = _player_colors[i]

	for i in range(min(player_count, players.size())):
		var p = players[i]
		values[i] = int(p.window_damage)

	# Update pie chart first.
	if is_instance_valid(_pie):
		_pie.visible = true
		if player_count <= 0:
			_pie.visible = false
		else:
			_pie.set_pie(values, colors)

	# Update labels.
	for i in range(MAX_PLAYERS):
		var idx = i
		var visible_row = idx < player_count
		if is_instance_valid(_damage_labels[i]):
			_damage_labels[i].visible = visible_row and _show_damage
		if is_instance_valid(_dps_labels[i]):
			_dps_labels[i].visible = visible_row and _show_dps

		if not visible_row:
			continue

		var p = players[idx]
		var dmg = int(p.window_damage)
		var dps = float(p.window_dps)

		var dmg_txt = _format_damage(dmg)
		var dmg_rich = "[color=%s][P%d][/color] %s" % [_color_to_hex(_player_colors[i]), i + 1, dmg_txt]
		if is_instance_valid(_damage_labels[i]):
			_damage_labels[i].bbcode_text = dmg_rich

		if is_instance_valid(_dps_labels[i]):
			_dps_labels[i].text = "%0.1f" % dps

func _get_mod_options() -> Node:
	# Navigate the ModLoader tree like other mods do.
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

func _format_damage(dmg: int) -> String:
	# Prefer Brotato's formatter, but fall back if unavailable.
	if typeof(Text) != TYPE_NIL:
		return Text.get_formatted_number(dmg)
	return str(dmg)

func _color_to_hex(c: Color) -> String:
	# RichTextLabel uses HTML-ish hex colors.
	var r = int(clamp(c.r, 0.0, 1.0) * 255.0)
	var g = int(clamp(c.g, 0.0, 1.0) * 255.0)
	var b = int(clamp(c.b, 0.0, 1.0) * 255.0)
	return "%02x%02x%02x" % [r, g, b]

