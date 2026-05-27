extends Control

const MAX_PLAYERS = 4

var _meter = null
var _font = null
var _colors = [
	Color(0.20, 0.78, 0.60, 1.0),
	Color(0.95, 0.45, 0.20, 1.0),
	Color(0.65, 0.25, 0.95, 1.0),
	Color(0.35, 0.55, 0.98, 1.0)
]
var _outline = Color(0.0, 0.0, 0.0, 0.85)
var _fill_alpha = 0.35

func set_meter(meter) -> void:
	_meter = meter

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0
	anchor_right = 0
	anchor_top = 1
	anchor_bottom = 1
	margin_left = 14
	margin_right = 390
	margin_top = -150
	margin_bottom = -10
	_font = preload("res://resources/fonts/actual/base/font_26_outline.tres")
	set_process(true)

func _process(_delta) -> void:
	update()

func _draw() -> void:
	if not is_instance_valid(_meter):
		return
	if _font == null:
		return

	var stats = _meter.get_meter_stats()
	var player_count = int(stats["player_count"])
	var totals = stats["total_damage"]
	var current_dps = stats["current_dps"]
	var max_dps = stats["max_dps"]

	draw_rect(Rect2(Vector2(0, 0), rect_size), Color(0.0, 0.0, 0.0, 0.55), true)

	var radius = 42.0
	var center = Vector2(54, rect_size.y - 56)
	var text_left = 112.0
	var bar_left = 210.0
	var bar_width = 96.0
	var bar_height = 18.0
	var row_height = 24.0
	var row_top = 36.0
	var ascent = _font.get_ascent()
	var highest_max = 0.0

	for i in range(min(player_count, MAX_PLAYERS)):
		if float(max_dps[i]) > highest_max:
			highest_max = float(max_dps[i])

	draw_string(_font, Vector2(10, 24), "Druotic DPSMeter", Color(1.0, 1.0, 1.0, 1.0))
	_draw_pie(center, radius, totals, player_count)

	for i in range(min(player_count, MAX_PLAYERS)):
		var y = row_top + row_height * i
		var color = _get_player_color(i)
		var total_text = "[P%d] %s" % [i + 1, _format_int(int(totals[i]))]
		draw_string(_font, Vector2(text_left, y + ascent), total_text, color)

		var max_value = float(max_dps[i])
		var current_value = float(current_dps[i])
		var fill_width = bar_width
		if highest_max > 0.0001:
			fill_width = bar_width * (max_value / highest_max)

		_draw_bar(Vector2(bar_left, y), fill_width, bar_height, Color(color, _fill_alpha))
		draw_string(_font, Vector2(bar_left + bar_width + 12, y + ascent), _format_float(max_value), color)

		var marker_x = bar_left
		if max_value > 0.0001:
			marker_x = bar_left + clamp(current_value / max_value, 0.0, 1.0) * fill_width
		draw_line(Vector2(marker_x, y), Vector2(marker_x, y + bar_height), color, 4.0)

func _get_player_color(player_index):
	if typeof(CoopService) != TYPE_NIL:
		return Color(CoopService.get_player_color(player_index), 1.0)
	return _colors[player_index]

func _draw_pie(center, radius, totals, player_count) -> void:
	var total = 0.0
	for i in range(min(player_count, MAX_PLAYERS)):
		total += float(totals[i])

	if total <= 0.0001:
		draw_circle(center, radius, Color(_get_player_color(0), _fill_alpha))
		_draw_circle_outline(center, radius)
		return

	var angle = -PI / 2.0
	for i in range(min(player_count, MAX_PLAYERS)):
		var value = float(totals[i])
		if value <= 0.0:
			continue
		var next_angle = angle + (value / total) * PI * 2.0
		_draw_slice(center, radius, angle, next_angle, Color(_get_player_color(i), _fill_alpha))
		angle = next_angle

	_draw_circle_outline(center, radius)

func _draw_slice(center, radius, angle_from, angle_to, color) -> void:
	var points = PoolVector2Array()
	points.append(center)
	var segments = 48
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = lerp(angle_from, angle_to, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polygon(points, [color])

func _draw_circle_outline(center, radius) -> void:
	var segments = 64
	for i in range(segments):
		var a = PI * 2.0 * float(i) / float(segments)
		var b = PI * 2.0 * float(i + 1) / float(segments)
		var p1 = center + Vector2(cos(a), sin(a)) * radius
		var p2 = center + Vector2(cos(b), sin(b)) * radius
		draw_line(p1, p2, _outline, 2.5)

func _draw_bar(pos, width, height, color) -> void:
	var rect = Rect2(pos, Vector2(width, height))
	draw_rect(rect, color, true)
	draw_line(pos, pos + Vector2(width, 0), _outline, 2.5)
	draw_line(pos + Vector2(width, 0), pos + Vector2(width, height), _outline, 2.5)
	draw_line(pos + Vector2(width, height), pos + Vector2(0, height), _outline, 2.5)
	draw_line(pos + Vector2(0, height), pos, _outline, 2.5)

func _format_int(value) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (value / 1000.0)
	return str(value)

func _format_float(value) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return "%.1f" % value
