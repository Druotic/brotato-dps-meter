extends "res://ui/menus/run/base_end_run.gd"

const MOD_MAIN_PATH = "/root/ModLoader/Druotic-DamageChart"

var _toggle_damage_button = null

func _ready() -> void:
	._ready()
	call_deferred("_add_toggle_damage_button")

func _exit_tree() -> void:
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main:
		mod_main.set_run_overlay_visible(false)

func _add_toggle_damage_button() -> void:
	if not is_instance_valid(_restart_button):
		return

	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main and mod_main.is_solo_hidden():
		return

	var buttons_container = _restart_button.get_parent()
	if not is_instance_valid(buttons_container):
		return

	_toggle_damage_button = Button.new()
	_toggle_damage_button.name = "ToggleDamageButton"
	_toggle_damage_button.rect_min_size = _restart_button.rect_min_size
	_toggle_damage_button.size_flags_horizontal = _restart_button.size_flags_horizontal
	_toggle_damage_button.size_flags_vertical = _restart_button.size_flags_vertical
	_toggle_damage_button.focus_mode = _restart_button.focus_mode
	_toggle_damage_button.connect("pressed", self, "_on_ToggleDamageButton_pressed")

	buttons_container.add_child(_toggle_damage_button)
	buttons_container.move_child(_toggle_damage_button, _restart_button.get_index())

	if mod_main:
		mod_main.prepare_end_run_display()
		mod_main.set_run_overlay_visible(true)
		_update_toggle_damage_button_text(true)

func _on_RestartButton_pressed() -> void:
	_reset_damage_chart_run()
	._on_RestartButton_pressed()

func _on_NewRunButton_pressed() -> void:
	_reset_damage_chart_run()
	._on_NewRunButton_pressed()

func _on_ExitButton_pressed() -> void:
	_reset_damage_chart_run()
	._on_ExitButton_pressed()

func _reset_damage_chart_run() -> void:
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main:
		mod_main.on_run_reset(true)

func _on_ToggleDamageButton_pressed() -> void:
	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if not mod_main:
		return

	var stats = mod_main.get_meter_stats()
	var visible = not stats["use_run_totals"]
	mod_main.set_run_overlay_visible(visible)
	_update_toggle_damage_button_text(visible)

func _update_toggle_damage_button_text(visible: bool) -> void:
	if not is_instance_valid(_toggle_damage_button):
		return

	_toggle_damage_button.text = "Hide Damage" if visible else "Show Damage"
