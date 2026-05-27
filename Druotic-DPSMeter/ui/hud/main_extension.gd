extends "res://main.gd"

# Injects the DPS overlay onto a root CanvasLayer, matching the reference mod's
# approach.

const OVERLAY_SCENE_PATH = "res://mods-unpacked/Druotic-DPSMeter/ui/hud/dps_overlay.tscn"

var _overlay_layer = null

func _enter_tree():
	var overlay_scene = load(OVERLAY_SCENE_PATH)
	if overlay_scene == null:
		return

	var overlay = overlay_scene.instance()
	overlay.name = "DpsMeterOverlay"

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	_overlay_layer.add_child(overlay)
	get_tree().get_root().add_child(_overlay_layer)

func _exit_tree():
	._exit_tree()
	if _overlay_layer and _overlay_layer.is_inside_tree():
		_overlay_layer.queue_free()
		_overlay_layer = null
