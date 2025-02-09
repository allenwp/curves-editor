@tool
class_name LinearCurveComparison
extends Node2D

@export var option_b: bool = false

@export var agx_ref_log2_middle_grey: float = 0.18
@export var agx_ref_log2_min: float = -10.0
@export var agx_ref_log2_max: float = 6.5

func reference_curve(x: float) -> float:
	return agx_reference(x)

func approx_curve(x: float) -> float:
	if option_b:
		return rational_interpolation(x)
	else:
		return krzysztof_narkowicz_aces(x)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func krzysztof_narkowicz_aces(x: float) -> float:
	x *= 0.6
	var a = 2.51;
	var b = 0.03;
	var c = 2.43;
	var d = 0.59;
	var e = 0.14;
	return (x*(a*x+b))/(x*(c*x+d)+e);

func rational_interpolation(x: float) -> float:
	# RationalInterpolation[agxCurve[x], {x, 2, 2}, {x, kLinearMin, kLinearMax}, Bias -> -0.5109]
	return (-0.00169047 + 1.49227 *x + 0.194039 * x * x)/(1 + 1.86073*x + 0.167678 * x * x)

func minimax_approxmiation(x: float) -> float:
	#MiniMaxApproximation[agxCurve[x], {x, {kLinearMin, kLinearMax}, 2, 2},Brake -> {200, 200}, MaxIterations -> 10000][[2, 1]]
	return (-0.000264666 + 1.50561 * x + 0.225389 * x * x)/(1 + 1.91729 * x + 0.196494 * x * x);

#region AgX Reference
func log2(value: float) -> float:
	return log(value) / log(2)

func scale_function(transition_x, transition_y, power, slope) -> float:
	var term_a: float = (slope * (1.0 - transition_x)) ** (-1.0 * power);
	var term_b: float = (((slope * (1.0 - transition_x)) / (1.0 - transition_y)) ** power) - 1.0
	return (term_a * term_b) ** (-1.0 / power)

func exponential_curve(x_in, scale_input, slope, power, transition_x, transition_y) -> float:
	var input: float = ((slope * (x_in - transition_x)) / scale_input)
	var result: float = (scale_input * exponential(input, power)) + transition_y
	# Even when x_in is non-negative, rounding error can cause the result to be -0.
	# This clipping deals with both cases of negative input and rounding error.
	return max(result, 0.0)

func exponential(x_in, power) -> float:
	var result: float = x_in / ((1 + (x_in ** power)) ** (1 / power))
	return result

func calculate_sigmoid(x: float) -> float:
	const slope: float = 2.4
	const power: float = 1.5
	var pivot_x: float = abs(agx_ref_log2_min/(agx_ref_log2_max  - agx_ref_log2_min))
	var pivot_y: float = agx_ref_log2_middle_grey ** (1.0 / 2.4)

	var scaleValue
	if x < pivot_x:
		scaleValue = -1.0 * scale_function(1.0 - pivot_x, 1.0 - pivot_y, power, slope)
	else:
		scaleValue = scale_function(pivot_x, pivot_y, power, slope)

	return exponential_curve(x, scaleValue, slope, power, pivot_x, pivot_y)

# log_encoding_Log2 from colour/models/rgb/transfer_functions/log.py of colour science package
func log_encoding_Log2(lin: float, middle_grey: float, min_exposure: float, max_exposure: float) -> float:
	var lg2 = log2(lin / middle_grey)
	var log_norm = (lg2 - min_exposure) / (max_exposure - min_exposure)
	return log_norm # Might be negative, but negatives are clipped later.

func agx_reference(color: float) -> float:
	color = max(color, 1e-10);

	color = log_encoding_Log2(color, agx_ref_log2_middle_grey, agx_ref_log2_min, agx_ref_log2_max)

	# Apply sigmoid function approximation.
	color = calculate_sigmoid(color);

	# Convert back to linear before applying outset matrix.
	color = pow(color, 2.4)

	# Blender's lusRGB.compensate_low_side is too complex for this shader, so
	# simply return the color, even if it has negative components. These negative
	# components may be useful for subsequent color adjustments.
	return color;
#endregion