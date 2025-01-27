@tool
extends Line2D

@export var zero: float
@export var one: float
@export var white: float

@export var LOG2_MIN: float = -10.0
@export var LOG2_MAX: float = +6.5
@export var MIDDLE_GRAY: float = 0.18

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var array: PackedVector2Array
	var num_points: float = 4096.0
	var min_stops = -12
	var max_stops = 4
	for i in range(num_points):
		var val: float = (i / (num_points - 1)) * (max_stops - min_stops) + min_stops
		val = pow(2.0, val) # convert from log2 encoding to linear encoding

		#var y_val: Vector3 = tonemap_linear(Vector3(val, val, val))
		#var y_val: Vector3 = tonemap_reinhard(Vector3(val, val, val))
		#var y_val: Vector3 = tonemap_filmic(Vector3(val, val, val))
		#var y_val: Vector3 = tonemap_aces(Vector3(val, val, val), white)
		var y_val: Vector3 = tonemap_agx(Vector3(val, val, val))

		# clip to [0.0, 1.0]
		y_val.x = maxf(minf(y_val.x, 1.0), 0.0)
		y_val.y = maxf(minf(y_val.y, 1.0), 0.0)
		y_val.z = maxf(minf(y_val.z, 1.0), 0.0)

		if i == 0:
			zero = y_val.x
		elif i == num_points - 1:
			one = y_val.x

		y_val.x = maxf(0.00001, y_val.x) # prevent log2(0)

		# to display y axis in log2 space: (log2(y_val.x) + abs(min_stops)) / (max_stops - min_stops) * -1000.0
		# to display y axis in linear space: y_val.x * -1000.0
		array.push_back(Vector2((log2(val) + abs(min_stops)) / (max_stops - min_stops)  * 1000.0, (log2(y_val.x) + abs(min_stops)) / (max_stops - min_stops) * -1000.0))
		#array.push_back(Vector2(pow(val, 1/2.2)  * 1000.0, pow(y_val.x, 1/2.2) * -1000.0))
		#array.push_back(Vector2(val / ((pow(2, max_stops) - (pow(2, min_stops)))) * 1000.0, y_val.x * -1000.0))
	points = array



func log2(value: float) -> float:
	return log(value) / log(2)


func vec3(value: float) -> Vector3:
	return Vector3(value, value, value)

func tonemap_linear(color: Vector3) -> Vector3:
	return color


func tonemap_reinhard(color: Vector3) -> Vector3:
	var white_squared: float = white * white;
	var white_squared_color: Vector3 = white_squared * color;
	#Equivalent to color * (1 + color / white_squared) / (1 + color)
	return (white_squared_color + color * color) / (white_squared_color + Vector3(white_squared, white_squared, white_squared))


func tonemap_filmic(color: Vector3) -> Vector3:
	# exposure bias: input scale (color *= bias, white *= bias) to make the brightness consistent with other tonemappers
	# also useful to scale the input to the range that the tonemapper is designed for (some require very high input values)
	# has no effect on the curve's general shape or visual properties
	const exposure_bias = 2.0
	const A = 0.22 * exposure_bias * exposure_bias # bias baked into constants for performance
	const B = 0.30 * exposure_bias
	const C = 0.10
	const D = 0.20
	const E = 0.01
	const F = 0.30

	var color_tonemapped: Vector3 = ((color * (A * color + vec3(C * B)) + vec3(D) * E) / (color * (A * color + vec3(B)) + vec3(D) * F)) - vec3(E / F);
	var white_tonemapped: float = ((white * (A * white + C * B) + D * E) / (white * (A * white + B) + D * F)) - E / F;

	return color_tonemapped / white_tonemapped;

func tonemap_aces(color: Vector3, white: float) -> Vector3:
	const exposure_bias = 1.8
	const A = 0.0245786
	const B = 0.000090537
	const C = 0.983729
	const D = 0.432951
	const E = 0.238081

	# Exposure bias baked into transform to save shader instructions. Equivalent to `color *= exposure_bias`
	var rgb_to_rrt: Basis = Basis()
	rgb_to_rrt.x = Vector3(0.59719 * exposure_bias, 0.35458 * exposure_bias, 0.04823 * exposure_bias)
	rgb_to_rrt.y = Vector3(0.07600 * exposure_bias, 0.90834 * exposure_bias, 0.01566 * exposure_bias)
	rgb_to_rrt.z = Vector3(0.02840 * exposure_bias, 0.13383 * exposure_bias, 0.83777 * exposure_bias)

	var odt_to_rgb: Basis = Basis()
	odt_to_rgb.x = Vector3(1.60475, -0.53108, -0.07367)
	odt_to_rgb.y = Vector3(-0.10208, 1.10813, -0.00605)
	odt_to_rgb.z = Vector3(-0.00327, -0.07276, 1.07602)

	color *= rgb_to_rrt;
	var color_tonemapped: Vector3 = (color * (color + vec3(A)) - vec3(B)) / (color * (C * color + vec3(D)) + vec3(E));
	color_tonemapped *= odt_to_rgb;

	white *= exposure_bias;
	var white_tonemapped: float = (white * (white + A) - B) / (white * (C * white + D) + E);

	return color_tonemapped / white_tonemapped;


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

func calculate_sigmoid(x_in: float) -> float:
	const slope: float = 2.4
	const power: float = 1.5
	var pivot_x: float = abs(LOG2_MIN/(LOG2_MAX  - LOG2_MIN))
	var pivot_y: float = MIDDLE_GRAY ** (1.0 / 2.4)

	var scaleValue
	if x_in < pivot_x:
		scaleValue = -1.0 * scale_function(1.0 - pivot_x, 1.0 - pivot_y, power, slope)
	else:
		scaleValue = scale_function(pivot_x, pivot_y, power, slope)

	return exponential_curve(x_in, scaleValue, slope, power, pivot_x, pivot_y)

func tonemap_agx(color: Vector3) -> Vector3:
	# Combined linear sRGB to linear Rec 2020 and Blender AgX inset matrices:
	var srgb_to_rec2020_agx_inset_matrix: Basis = Basis()
	srgb_to_rec2020_agx_inset_matrix.x = Vector3(0.54490813676363087053, 0.14044005884001287035, 0.088827411851915368603)
	srgb_to_rec2020_agx_inset_matrix.y = Vector3(0.37377945959812267119, 0.75410959864013760045, 0.17887712465043811023)
	srgb_to_rec2020_agx_inset_matrix.z = Vector3(0.081384976686407536266, 0.10543358536857773485, 0.73224999956948382528);

	# Combined inverse AgX outset matrix and linear Rec 2020 to linear sRGB matrices.
	var agx_outset_rec2020_to_srgb_matrix: Basis = Basis()
	agx_outset_rec2020_to_srgb_matrix.x = Vector3(1.9645509602733325934, -0.29932243390911083839, -0.16436833806080403409)
	agx_outset_rec2020_to_srgb_matrix.y = Vector3(-0.85585845117807513559, 1.3264510741502356555, -0.23822464068860595117)
	agx_outset_rec2020_to_srgb_matrix.z = Vector3(-0.10886710826831608324, -0.027084020983874825605, 1.402665347143271889);

	LOG2_MAX = log2(white / MIDDLE_GRAY)

	# Large negative values in one channel and large positive values in other
	# channels can result in a colour that appears darker and more saturated than
	# desired after passing it through the inset matrix. For this reason, it is
	# best to prevent negative input values.
	# This is done before the Rec. 2020 transform to allow the Rec. 2020
	# transform to be combined with the AgX inset matrix. This results in a loss
	# of color information that could be correctly interpreted within the
	# Rec. 2020 color space as positive RGB values, but it is less common for Godot
	# to provide this function with negative sRGB values and therefore not worth
	# the performance cost of an additional matrix multiplication.
	# A value of 2e-10 intentionally introduces insignificant error to prevent
	# log2(0.0) after the inset matrix is applied; color will be >= 1e-10 after
	# the matrix transform.
	color.x = max(color.x, 2e-10);
	color.y = max(color.y, 2e-10);
	color.z = max(color.z, 2e-10);

	# Do AGX in rec2020 to match Blender and then apply inset matrix.
	color = srgb_to_rec2020_agx_inset_matrix * color;

	# Log2 space encoding.
	# Must be clamped because agx_contrast_approx may not work
	# well with values outside of the range [0.0, 1.0]
	# color.x = to_agx_log2(color.x)
	# color.y = to_agx_log2(color.y)
	# color.z = to_agx_log2(color.z)

	color.x = log_encoding_Log2(color.x, MIDDLE_GRAY, LOG2_MIN, LOG2_MAX)
	color.y = log_encoding_Log2(color.y, MIDDLE_GRAY, LOG2_MIN, LOG2_MAX)
	color.z = log_encoding_Log2(color.z, MIDDLE_GRAY, LOG2_MIN, LOG2_MAX)

	# Apply sigmoid function approximation.
	color.x = calculate_sigmoid(color.x);
	color.y = calculate_sigmoid(color.y);
	color.z = calculate_sigmoid(color.z);

	# Convert back to linear before applying outset matrix.
	color = Vector3(pow(color.x, 2.4), pow(color.y, 2.4), pow(color.z, 2.4));

	# Apply outset to make the result more chroma-laden and then go back to linear sRGB.
	color = agx_outset_rec2020_to_srgb_matrix * color;

	# Blender's lusRGB.compensate_low_side is too complex for this shader, so
	# simply return the color, even if it has negative components. These negative
	# components may be useful for subsequent color adjustments.
	return color;


# func to_agx_log2(val: float) -> float:
# 	var min_ev: float = log2(pow(2.0, LOG2_MIN) * MIDDLE_GRAY)
# 	var max_ev: float = log2(pow(2.0, LOG2_MAX) * MIDDLE_GRAY)
# 	val = clamp(log2(val), min_ev, max_ev)
# 	val = (val - min_ev) / (max_ev - min_ev)
# 	return val

# log_encoding_Log2 from colour/models/rgb/transfer_functions/log.py of colour science package
func log_encoding_Log2(lin: float, middle_grey: float, min_exposure: float, max_exposure: float) -> float:
	var lg2 = log2(lin / middle_grey)
	var log_norm = (lg2 - min_exposure) / (max_exposure - min_exposure)
	return log_norm # Might be negative, but negatives are clipped later.
