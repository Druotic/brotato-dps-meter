extends Control

# Simple filled pie chart (Godot 3-style drawing) for the rolling DPS window.

const DEFAULT_STEPS: int = 24

var _values: Array = []
var _colors: Array = []

var _radius: float = 40.0
var _steps: int = DEFAULT_STEPS

func set_pie(values: Array, colors: Array) -> void:
	_values = values.duplicate()
	_colors = colors.duplicate()
	update()

func _draw() -> void:
	var size = rect_size
	var min_dim = min(size.x, size.y)
	var radius = min_dim * 0.5
	var center = Vector2(size.x * 0.5, size.y * 0.5)

	if _values.empty():
		return

	var total: float = 0.0
	for v in _values:
		total += float(v)

	# Don't draw when there is no data.
	if total <= 0.00001:
		return

	var start_angle = -PI / 2.0
	var current_angle = start_angle

	for i in range(min(_values.size(), _colors.size())):
		var v = float(_values[i])
		if v <= 0.0:
			continue

		var frac = v / total
		var end_angle = current_angle + frac * PI * 2.0
		var color = _colors[i]

		# Build a triangle fan polygon for the filled slice.
		var points = PoolVector2Array()
		points.append(center)
		for s in range(_steps + 1):
			var t = float(s) / float(_steps)
			var ang = lerp(current_angle, end_angle, t)
			points.append(center + Vector2(cos(ang), sin(ang)) * radius)

		draw_polygon(points, [color])
		current_angle = end_angle

