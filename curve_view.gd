@tool
class_name CurveView
extends Node2D

enum EncodingType { LINEAR, LOG2}

@export var curves: LinearCurveComparison

@export var num_points: int = 1000

@export var x_encoding_type: EncodingType = EncodingType.LINEAR
@export var y_encoding_type: EncodingType = EncodingType.LINEAR
@export var linear_min_x: float = 0.0
@export var linear_max_x: float = 16.3
@export var linear_min_y: float = 0.0
@export var linear_max_y: float = 1.0
@export var log2_middle_grey: float = 1.0
@export var log2_min_x: float = -12.0
@export var log2_max_x: float = 4.0
@export var log2_min_y: float = -12.0
@export var log2_max_y: float = 4.0
@export var clip: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !curves:
		return

	match x_encoding_type:
		EncodingType.LINEAR:
			%XLowerLable.text = "%.2f" % linear_min_x
			%XUpperLable.text = "%.2f" % linear_max_x
			%XLable.text = "Input (linear scale)"
			%XMiddleGreyLine.position.x = (log2_middle_grey - linear_min_x) / (linear_max_x - linear_min_x) * 1000.0
		EncodingType.LOG2:
			%XLowerLable.text = "%+.2f" % log2_min_x
			%XUpperLable.text = "%+.2f" % log2_max_x
			%XLable.text = "Input (log2 scale, middle grey: %.2f)" % log2_middle_grey
			%XMiddleGreyLine.position.x = (log2(log2_middle_grey / log2_middle_grey) + abs(log2_min_x)) / (log2_max_x - log2_min_x) * 1000.0
	%XMiddleGreyLine.visible = %XMiddleGreyLine.position.x >= 0.0 && %XMiddleGreyLine.position.x <= 1000.0

	match y_encoding_type:
		EncodingType.LINEAR:
			%YLowerLable.text = "%.2f" % linear_min_y
			%YUpperLable.text = "%.2f" % linear_max_y
			%YLable.text = "Output (linear scale)"
			%YMiddleGreyLine.position.y = (1.0 - (log2_middle_grey - linear_min_y) / (linear_max_y - linear_min_y)) * 1000.0
		EncodingType.LOG2:
			%YLowerLable.text = "%+.2f" % log2_min_y
			%YUpperLable.text = "%+.2f" % log2_max_y
			%YLable.text = "Output (log2 scale, middle grey: %.2f)" % log2_middle_grey
			%YMiddleGreyLine.position.y = (1.0 - (log2(log2_middle_grey / log2_middle_grey) - log2_min_y) / (log2_max_y - log2_min_y)) * 1000.0
	%YMiddleGreyLine.visible = %YMiddleGreyLine.position.y >= 0.0 && %YMiddleGreyLine.position.y <= 1000.0

	var reference_points: PackedVector2Array
	var approx_points: PackedVector2Array
	for i in range(num_points):
		var x: float

		match x_encoding_type:
			EncodingType.LINEAR:
				x = (float(i) / (num_points - 1)) * (linear_max_x - linear_min_x) + linear_min_x
			EncodingType.LOG2:
				x = (float(i) / (num_points - 1)) * (log2_max_x - log2_min_x) + log2_min_x
				x = pow(2.0, x) * log2_middle_grey # convert from log2 encoding to linear encoding

		var y_reference: float = curves.reference_curve(x)
		var y_approx: float = curves.approx_curve(x)

		# scale x from linear encoding to match the [0,1000] graph range
		match x_encoding_type:
			EncodingType.LINEAR:
				x = (x - linear_min_x) / (linear_max_x - linear_min_x) * 1000.0
			EncodingType.LOG2:
				x = (log2(x / log2_middle_grey) + abs(log2_min_x)) / (log2_max_x - log2_min_x) * 1000.0

		# scale y from linear encoding to match the [0,-1000] graph range
		match y_encoding_type:
			EncodingType.LINEAR:
				y_reference = (y_reference - linear_min_y) / (linear_max_y - linear_min_y) * -1000.0
				y_approx = (y_approx - linear_min_y) / (linear_max_y - linear_min_y) * -1000.0
			EncodingType.LOG2:
				y_reference = maxf(1e-10, y_reference / log2_middle_grey) # prevent log2(0)
				y_approx = maxf(1e-10, y_approx / log2_middle_grey) # prevent log2(0)
				y_reference = (log2(y_reference) - log2_min_y) / (log2_max_y - log2_min_y) * -1000.0
				y_approx = (log2(y_approx) - log2_min_y) / (log2_max_y - log2_min_y) * -1000.0
		
		if !clip || (x >= 0.0 && x <= 1000.0 && y_reference <= 0.0 && y_reference >= -1000.0):
			reference_points.push_back(Vector2(x, y_reference))
		if !clip || (x >= 0.0 && x <= 1000.0 && y_approx <= 0.0 && y_approx >= -1000.0):
			approx_points.push_back(Vector2(x, y_approx))

	%ReferenceLine.points = reference_points
	%ApproxLine.points = approx_points

func log2(value: float) -> float:
	return log(value) / log(2)