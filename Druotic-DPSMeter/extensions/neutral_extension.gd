extends 'res://entities/units/neutral/neutral.gd'

# Records actual HP removed from neutral units (props, trees, etc.) so they
# contribute to per-player damage totals without overkill inflation.

const MOD_MAIN_PATH = "/root/ModLoader/Druotic-DPSMeter"

func take_damage(value: int, args) -> Array:
	var result = .take_damage(value, args)
	if result.size() < 2:
		return result

	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main and args != null:
		mod_main.record_damage(_resolve_player_index(args), int(result[1]))

	return result

func _resolve_player_index(args) -> int:
	var player_index = -1
	if args != null:
		player_index = int(args.from_player_index)
	if player_index >= 0:
		return player_index

	return _get_charmed_by_player_index(_get_attacker(args))

func _get_attacker(args):
	if args == null:
		return null

	var hitbox = args.get("hitbox")
	if hitbox == null:
		return null

	return hitbox.get("from")

func _get_charmed_by_player_index(node) -> int:
	if not is_instance_valid(node):
		return -1

	var direct = _get_charm_owner_from_node(node)
	if direct >= 0:
		return direct

	for child in node.get_children():
		var child_owner = _get_charm_owner_from_node(child)
		if child_owner >= 0:
			return child_owner

		if child.get_name() == "EffectBehaviors":
			for effect_behavior in child.get_children():
				var effect_owner = _get_charm_owner_from_node(effect_behavior)
				if effect_owner >= 0:
					return effect_owner

	return -1

func _get_charm_owner_from_node(node) -> int:
	if not is_instance_valid(node):
		return -1

	var charmed = node.get("charmed")
	var charmed_by = node.get("charmed_by_player_index")
	if charmed == true and charmed_by != null:
		return int(charmed_by)

	return -1
