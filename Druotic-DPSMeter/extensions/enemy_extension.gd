extends 'res://entities/units/enemies/enemy.gd'

# Hooks enemy damage so we can record *actual* HP removed.
# This prevents overkill from inflating DPS.

const MOD_MAIN_PATH = "/root/ModLoader/Druotic-DPSMeter"

func take_damage(value: int, args) -> Array:
	var result = .take_damage(value, args)
	if result.size() < 2:
		return result

	var mod_main = get_node_or_null(MOD_MAIN_PATH)
	if mod_main and args != null:
		var charm_player_index = _get_charmed_by_player_index(_get_attacker(args))
		if charm_player_index >= 0:
			mod_main.record_damage(charm_player_index, int(result[0]), int(result[1]), true)
		else:
			mod_main.record_damage(int(args.from_player_index), int(result[0]), int(result[1]), false)

	return result

func _get_attacker(args):
	if args == null:
		return null

	var hitbox = args.get("hitbox")
	if hitbox == null:
		return null

	return hitbox.get("from")

func _get_charmed_by_player_index(node, depth = 0) -> int:
	if not is_instance_valid(node):
		return -1
	if depth > 6:
		return -1

	var direct = _get_charm_owner_from_node(node)
	if direct >= 0:
		return direct

	var owner = node.get("owner")
	if is_instance_valid(owner) and owner != node:
		var owner_index = _get_charmed_by_player_index(owner, depth + 1)
		if owner_index >= 0:
			return owner_index

	var parent = node.get_parent()
	if is_instance_valid(parent) and parent != node:
		var parent_index = _get_charmed_by_player_index(parent, depth + 1)
		if parent_index >= 0:
			return parent_index

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
	if charmed == true:
		var player_index = _get_player_index_from_node(node)
		if player_index >= 0:
			return player_index

	return -1

func _get_player_index_from_node(node) -> int:
	var player_index = node.get("charmed_by_player_index")
	if player_index != null:
		return int(player_index)

	player_index = node.get("player_index")
	if player_index != null:
		return int(player_index)

	player_index = node.get("from_player_index")
	if player_index != null:
		return int(player_index)

	player_index = node.get("source_player_index")
	if player_index != null:
		return int(player_index)

	var source = node.get("source")
	if is_instance_valid(source):
		player_index = source.get("player_index")
		if player_index != null:
			return int(player_index)

	return -1
