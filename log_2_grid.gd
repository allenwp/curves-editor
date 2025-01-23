@tool
extends Node2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	var value: float = 0.0
	for line: Node2D in get_children():
		if line != null:
			configure_line(line, 2 ** value)
			value += 2 ** value


func configure_line(line: Node2D, value: float) -> void:
	line.position.x = (value / 16) * 1000
	(line.find_child("Label") as Label).text = "%.1f" % value
