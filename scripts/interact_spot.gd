extends Node3D
## Something the player can press E on (the bed, the market stall, the pond...).
## The player finds the closest node in the "interactable" group and asks it
## for a prompt; anything with get_prompt()/interact() works, including NPCs
## and farm tiles.

var prompt_func: Callable     # func(player) -> String  ("" = nothing to do here)
var action_func: Callable     # func(player) -> void
var interact_range := 2.5
## If > 0, the spot is a ring: you must stand within interact_range of this
## radius (used for the pond edge).
var ring_radius := 0.0


func _ready() -> void:
	add_to_group("interactable")


func distance_to_player(player: Node3D) -> float:
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if ring_radius > 0.0:
		return abs(d - ring_radius)
	return d


func get_prompt(player: Node3D) -> String:
	return prompt_func.call(player) if prompt_func.is_valid() else ""


func interact(player: Node3D) -> void:
	if action_func.is_valid():
		action_func.call(player)
