extends PanelContainer
## Upgrade list — Workstream C implements branch rows.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List


func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	_refresh()


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_refresh()


func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	var placeholder := Label.new()
	placeholder.text = "Upgrades — Workstream C"
	list.add_child(placeholder)
