class_name RattlingController
extends Node
## Manages the pool of active Rattling agents — claims unclaimed litter balls,
## spawns/staggers new agents up to the upgraded count, and forwards the
## atmosphere tint. Scales cheaply to 25-50 concurrent agents (no physics).

const RattlingScript := preload("res://scripts/range/rattling.gd")

var _foreground: Node3D
var _littered_balls: Node3D
var _agents: Array = []
var _claimed_ids: Dictionary = {}
var _time_since_spawn: float = 999.0
var _atmosphere_tint: Color = Color.WHITE


func setup(_range_view: Node3D, foreground: Node3D, littered_balls: Node3D) -> void:
	_foreground = foreground
	_littered_balls = littered_balls
	EventBus.helper_toggled.connect(_on_helper_toggled)


## Toggled off — live agents finish carrying balls home (no lost payout) or
## walk back empty; no new spawns until re-enabled.
func _on_helper_toggled(helper: String, active: bool) -> void:
	if helper != "rattlings" or active:
		return
	for agent in _agents.duplicate():
		if not is_instance_valid(agent):
			continue
		if agent.should_release_claim():
			var litter_id: int = agent.claimed_litter_instance_id()
			if litter_id != -1:
				_claimed_ids.erase(litter_id)
		agent.retire()


func apply_atmosphere_tint(tint: Color) -> void:
	_atmosphere_tint = tint
	for agent in _agents:
		if is_instance_valid(agent):
			agent.apply_atmosphere_tint(tint)


func _process(delta: float) -> void:
	_time_since_spawn += delta
	if not GameState.rattlings_unlocked or not GameState.rattlings_active:
		return
	if _time_since_spawn < Balance.RATTLING_SPAWN_STAGGER_SEC:
		return
	_prune_stale_claims()
	var desired := int(GameState.rattling_stats.rattling_count)
	if _agents.size() >= desired:
		return
	var candidate := _pick_unclaimed_litter()
	if candidate == null:
		return
	_spawn_agent(candidate)
	_time_since_spawn = 0.0


func _prune_stale_claims() -> void:
	for id in _claimed_ids.keys():
		var node := instance_from_id(id)
		if node == null or not is_instance_valid(node):
			_claimed_ids.erase(id)


func _pick_unclaimed_litter() -> Sprite3D:
	if _littered_balls == null:
		return null
	var candidates: Array[Sprite3D] = []
	for child in _littered_balls.get_children():
		if not child is Sprite3D:
			continue
		if not child.get_meta("collectible", false):
			continue
		if _claimed_ids.has(child.get_instance_id()):
			continue
		candidates.append(child)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _spawn_agent(litter: Sprite3D) -> void:
	_claimed_ids[litter.get_instance_id()] = true
	var agent: Node3D = RattlingScript.new()
	_foreground.add_child(agent)
	agent.finished.connect(_on_agent_finished)
	agent.start(litter, GameState.rattling_stats.rattling_walk_speed, _atmosphere_tint)
	_agents.append(agent)


func _on_agent_finished(agent: Node3D) -> void:
	_agents.erase(agent)
	if is_instance_valid(agent):
		agent.queue_free()
