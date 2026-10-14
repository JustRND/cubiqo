class_name PieceDefinition
extends RefCounted
## Data-driven representation of a block puzzle piece shape, color palette entry, and metadata.
## All geometry and behavior derive strictly from its normalized relative cell coordinates.

var id: String = ""
var display_name: String = ""
var cells: Array[Vector2i] = []
var color_id: String = "cyan"
var color: Color = Color("38BDF8")
var weight: float = 1.0
var difficulty_rating: int = 1
var metadata: Dictionary = {}

## Curated vibrant mobile puzzle color palette.
const PALETTE: Dictionary = {
	"amber": Color("#F59E0B"),
	"coral": Color("#F43F5E"),
	"emerald": Color("#10B981"),
	"cyan": Color("#06B6D4"),
	"indigo": Color("#6366F1"),
	"violet": Color("#A855F7"),
	"orange": Color("#FB923C"),
	"lime": Color("#84CC16")
}

## High-contrast palette override for accessibility.
const HIGH_CONTRAST_PALETTE: Dictionary = {
	"amber": Color("#FFD60A"),
	"coral": Color("#FF2A55"),
	"emerald": Color("#00F59B"),
	"cyan": Color("#00E5FF"),
	"indigo": Color("#7B8CFF"),
	"violet": Color("#D96BFF"),
	"orange": Color("#FF851B"),
	"lime": Color("#B8FF01")
}


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_cells: Array = [],
	p_color_id: String = "cyan",
	p_weight: float = 1.0,
	p_difficulty_rating: int = 1,
	p_metadata: Dictionary = {}
) -> void:
	id = p_id
	display_name = p_display_name if p_display_name != "" else p_id
	color_id = p_color_id
	color = PALETTE.get(p_color_id, Color("#38BDF8"))
	weight = maxf(0.0, p_weight)
	difficulty_rating = clampi(p_difficulty_rating, 1, 5)
	metadata = p_metadata.duplicate(true)
	_set_normalized_cells(p_cells)


func _set_normalized_cells(raw_cells: Array) -> void:
	cells.clear()
	if raw_cells.is_empty():
		return

	var typed_cells: Array[Vector2i] = []
	var min_x: int = 999999
	var min_y: int = 999999

	for entry in raw_cells:
		var v: Vector2i
		if entry is Vector2i:
			v = entry
		elif entry is Vector2:
			v = Vector2i(int(entry.x), int(entry.y))
		elif entry is Array and entry.size() >= 2:
			v = Vector2i(int(entry[0]), int(entry[1]))
		else:
			continue
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
		typed_cells.append(v)

	var seen: Dictionary = {}
	for v in typed_cells:
		var norm := Vector2i(v.x - min_x, v.y - min_y)
		if not seen.has(norm):
			seen[norm] = true
			cells.append(norm)


## Validates that the piece has a non-empty ID, at least one cell, no duplicates, and normalized bounds.
func is_valid_definition() -> bool:
	if id.strip_edges() == "" or cells.is_empty():
		return false
	var min_x: int = 999999
	var min_y: int = 999999
	var seen: Dictionary = {}
	for c in cells:
		if c.x < 0 or c.y < 0:
			return false
		if seen.has(c):
			return false
		seen[c] = true
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
	return min_x == 0 and min_y == 0


func get_cell_count() -> int:
	return cells.size()


## Returns the width and height of the piece in grid cells.
func get_bounding_size() -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var max_x: int = 0
	var max_y: int = 0
	for c in cells:
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)
	return Vector2i(max_x + 1, max_y + 1)


## Returns the geometric center of the bounding box in cell units (e.g. (1.0, 1.0) for a 2x2 square).
func get_center_offset() -> Vector2:
	var bounds := get_bounding_size()
	return Vector2(bounds.x * 0.5, bounds.y * 0.5)


## Maps local cell offsets to board coordinates anchored at `origin`.
func get_world_cells(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.resize(cells.size())
	for i in range(cells.size()):
		result[i] = origin + cells[i]
	return result


func get_display_color(high_contrast: bool = false) -> Color:
	if high_contrast and HIGH_CONTRAST_PALETTE.has(color_id):
		return HIGH_CONTRAST_PALETTE[color_id]
	return color


func duplicate_piece(extra_metadata: Dictionary = {}) -> PieceDefinition:
	var merged_meta := metadata.duplicate(true)
	for k in extra_metadata.keys():
		merged_meta[k] = extra_metadata[k]
	return PieceDefinition.new(
		id,
		display_name,
		cells,
		color_id,
		weight,
		difficulty_rating,
		merged_meta
	)


## Returns the default catalog of data-driven piece definitions (16 distinct shapes).
static func create_default_catalog() -> Array[PieceDefinition]:
	return [
		# 1. Single square
		PieceDefinition.new(
			"single_1x1", "Single Square",
			[Vector2i(0, 0)],
			"amber", 1.2, 1
		),
		# 2. Two-block horizontal line
		PieceDefinition.new(
			"line_h2", "Horizontal 2-Line",
			[Vector2i(0, 0), Vector2i(1, 0)],
			"cyan", 1.15, 1
		),
		# 3. Three-block horizontal line
		PieceDefinition.new(
			"line_h3", "Horizontal 3-Line",
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"emerald", 1.1, 2
		),
		# 4. Four-block horizontal line
		PieceDefinition.new(
			"line_h4", "Horizontal 4-Line",
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
			"indigo", 0.9, 2
		),
		# 5. Five-block horizontal line
		PieceDefinition.new(
			"line_h5", "Horizontal 5-Line",
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
			"coral", 0.65, 3
		),
		# 6. Two-block vertical line
		PieceDefinition.new(
			"line_v2", "Vertical 2-Line",
			[Vector2i(0, 0), Vector2i(0, 1)],
			"cyan", 1.15, 1
		),
		# 7. Three-block vertical line
		PieceDefinition.new(
			"line_v3", "Vertical 3-Line",
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
			"emerald", 1.1, 2
		),
		# 8. Four-block vertical line
		PieceDefinition.new(
			"line_v4", "Vertical 4-Line",
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
			"indigo", 0.9, 2
		),
		# 9. Five-block vertical line
		PieceDefinition.new(
			"line_v5", "Vertical 5-Line",
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)],
			"coral", 0.65, 3
		),
		# 10. 2x2 square
		PieceDefinition.new(
			"square_2x2", "2x2 Square",
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			"orange", 1.1, 2
		),
		# 11. 3x3 square
		PieceDefinition.new(
			"square_3x3", "3x3 Square",
			[
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
			],
			"coral", 0.55, 3
		),
		# 12. L-shaped piece (standard 4-cell L)
		PieceDefinition.new(
			"l_shape", "L-Shape",
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
			"orange", 0.95, 2
		),
		# 13. Small 3-cell corner L
		PieceDefinition.new(
			"l_small", "Small Corner L",
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
			"lime", 1.1, 1
		),
		# 14. Large 5-cell L
		PieceDefinition.new(
			"l_large", "Large 3x3 L",
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
			"indigo", 0.7, 3
		),
		# 15. T-shaped piece
		PieceDefinition.new(
			"t_shape", "T-Shape",
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
			"violet", 0.95, 2
		),
		# 16. Zigzag piece (Z-shape)
		PieceDefinition.new(
			"z_shape", "Zigzag Z-Shape",
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
			"lime", 0.85, 2
		),
		# 17. Zigzag piece (S-shape mirror)
		PieceDefinition.new(
			"s_shape", "Zigzag S-Shape",
			[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
			"emerald", 0.85, 2
		)
	]
