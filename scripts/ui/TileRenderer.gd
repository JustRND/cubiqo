class_name TileRenderer
extends RefCounted
## Reusable, zero-allocation StyleBox renderer for rounded puzzle tiles, empty board cells, and previews.

var _empty_cell_box: StyleBoxFlat
var _block_shadow_box: StyleBoxFlat
var _block_main_box: StyleBoxFlat
var _block_highlight_box: StyleBoxFlat
var _ghost_box: StyleBoxFlat
var _line_preview_box: StyleBoxFlat


func _init() -> void:
	_empty_cell_box = StyleBoxFlat.new()
	_empty_cell_box.bg_color = Color("#0E172C")
	_empty_cell_box.border_color = Color("#1B294B")
	_empty_cell_box.set_border_width_all(1)

	_block_shadow_box = StyleBoxFlat.new()
	_block_main_box = StyleBoxFlat.new()
	_block_highlight_box = StyleBoxFlat.new()

	_ghost_box = StyleBoxFlat.new()
	_ghost_box.set_border_width_all(2)

	_line_preview_box = StyleBoxFlat.new()
	_line_preview_box.bg_color = Color(1.0, 0.93, 0.55, 0.34)
	_line_preview_box.border_color = Color(1.0, 0.96, 0.75, 0.85)
	_line_preview_box.set_border_width_all(2)


func _set_corners(box: StyleBoxFlat, radius: int) -> void:
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius


## Draws a recessed empty board cell.
func draw_empty_cell(canvas: CanvasItem, rect: Rect2) -> void:
	var r := maxi(4, int(rect.size.x * 0.18))
	_set_corners(_empty_cell_box, r)
	canvas.draw_style_box(_empty_cell_box, rect)


## Draws a rich, rounded puzzle block tile with bevel and soft top highlight.
func draw_block_tile(
	canvas: CanvasItem,
	rect: Rect2,
	base_color: Color,
	alpha: float = 1.0,
	scale_factor: float = 1.0
) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return

	var draw_rect := rect
	if absf(scale_factor - 1.0) > 0.001:
		var new_size := rect.size * scale_factor
		var offset := (rect.size - new_size) * 0.5
		draw_rect = Rect2(rect.position + offset, new_size)

	var radius := maxi(4, int(draw_rect.size.x * 0.20))
	var bevel_h := maxf(2.0, draw_rect.size.y * 0.08)

	# 1. Bottom bevel / base shadow layer
	var shadow_col := base_color.darkened(0.32)
	shadow_col.a = alpha
	_block_shadow_box.bg_color = shadow_col
	_set_corners(_block_shadow_box, radius)
	canvas.draw_style_box(_block_shadow_box, draw_rect)

	# 2. Main vibrant body shifted slightly above bottom bevel
	var main_rect := Rect2(
		draw_rect.position.x,
		draw_rect.position.y,
		draw_rect.size.x,
		maxf(4.0, draw_rect.size.y - bevel_h)
	)
	var fill_col := base_color
	fill_col.a = alpha
	_block_main_box.bg_color = fill_col
	_block_main_box.border_color = base_color.lightened(0.24)
	_block_main_box.border_color.a = alpha * 0.75
	_block_main_box.set_border_width_all(1)
	_set_corners(_block_main_box, radius)
	canvas.draw_style_box(_block_main_box, main_rect)

	# 3. Soft top inner highlight strip
	var gloss_margin := maxf(3.0, draw_rect.size.x * 0.12)
	var gloss_h := maxf(3.0, draw_rect.size.y * 0.22)
	if draw_rect.size.x > gloss_margin * 2.2 and main_rect.size.y > gloss_h * 1.5:
		var gloss_rect := Rect2(
			draw_rect.position.x + gloss_margin,
			draw_rect.position.y + gloss_margin * 0.65,
			draw_rect.size.x - gloss_margin * 2.0,
			gloss_h
		)
		var gloss_col := Color(1.0, 1.0, 1.0, 0.22 * alpha)
		_block_highlight_box.bg_color = gloss_col
		_set_corners(_block_highlight_box, maxi(2, int(radius * 0.6)))
		canvas.draw_style_box(_block_highlight_box, gloss_rect)


## Draws a valid ghost placement preview cell on the board.
func draw_ghost_tile(canvas: CanvasItem, rect: Rect2, base_color: Color) -> void:
	var radius := maxi(4, int(rect.size.x * 0.20))
	_ghost_box.bg_color = Color(base_color.r, base_color.g, base_color.b, 0.36)
	_ghost_box.border_color = Color(base_color.r, base_color.g, base_color.b, 0.90)
	_set_corners(_ghost_box, radius)
	canvas.draw_style_box(_ghost_box, rect)


## Draws a glowing highlight on cells belonging to a row or column that will clear if dropped.
func draw_line_clear_preview_overlay(canvas: CanvasItem, rect: Rect2) -> void:
	var radius := maxi(4, int(rect.size.x * 0.20))
	_set_corners(_line_preview_box, radius)
	canvas.draw_style_box(_line_preview_box, rect)
