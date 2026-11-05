extends Control
class_name WorldMapVisual

var world: Node

func set_world(value: Node) -> void:
	world = value
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	# Deep sea / parchment-style strategic map background.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#102b3a"))
	draw_rect(Rect2(8, 8, size.x - 16, size.y - 16), Color("#d4bd82"))

	# Irregular continent silhouette.
	var land := PackedVector2Array([
		Vector2(38, 82), Vector2(92, 48), Vector2(170, 40), Vector2(242, 58),
		Vector2(320, 38), Vector2(410, 72), Vector2(478, 120), Vector2(468, 205),
		Vector2(486, 292), Vector2(452, 372), Vector2(408, 448), Vector2(330, 470),
		Vector2(246, 500), Vector2(160, 478), Vector2(92, 442), Vector2(48, 370),
		Vector2(26, 282), Vector2(40, 190)
	])
	draw_colored_polygon(land, Color("#b8a36f"))
	draw_polyline(land, Color("#4b3a24"), 3.0, true)

	# Terrain shading / plains.
	draw_colored_polygon(PackedVector2Array([
		Vector2(115, 145), Vector2(190, 112), Vector2(275, 126), Vector2(325, 192),
		Vector2(278, 264), Vector2(190, 250), Vector2(120, 218)
	]), Color("#c7b77f"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(275, 278), Vector2(365, 240), Vector2(430, 278), Vector2(400, 370),
		Vector2(315, 390), Vector2(258, 340)
	]), Color("#ad9a66"))

	# Mountain ranges.
	for base in [Vector2(70,115), Vector2(105,125), Vector2(140,135), Vector2(350,95), Vector2(380,110), Vector2(410,130), Vector2(375,385), Vector2(405,400)]:
		_draw_mountain(base)

	# Forest clusters.
	for base in [Vector2(75,235), Vector2(105,260), Vector2(130,278), Vector2(215,410), Vector2(245,425), Vector2(440,215), Vector2(420,235)]:
		_draw_tree(base)

	# Main river and tributary.
	var river := PackedVector2Array([Vector2(310,55), Vector2(294,100), Vector2(300,145), Vector2(280,190), Vector2(292,235), Vector2(270,285), Vector2(278,335), Vector2(250,385), Vector2(245,450)])
	draw_polyline(river, Color("#4f9fba"), 7.0, false)
	var tributary := PackedVector2Array([Vector2(430,170), Vector2(390,185), Vector2(350,175), Vector2(300,190)])
	draw_polyline(tributary, Color("#67a9bd"), 4.0, false)

	# Roads between the major strategic regions.
	var roads := [
		[Vector2(92,150),Vector2(185,170),Vector2(292,190),Vector2(390,185)],
		[Vector2(185,170),Vector2(205,285),Vector2(270,335)],
		[Vector2(292,190),Vector2(345,275),Vector2(400,330)],
		[Vector2(205,285),Vector2(160,365),Vector2(245,450)],
		[Vector2(345,275),Vector2(315,390),Vector2(245,450)]
	]
	for road in roads:
		var pts := PackedVector2Array(road)
		draw_polyline(pts, Color("#705a37"), 5.0, false)
		draw_polyline(pts, Color("#cdb681"), 2.0, false)

	# Decorative border and compass.
	draw_rect(Rect2(12, 12, size.x - 24, size.y - 24), Color("#5a4426"), 2.0)
	draw_line(Vector2(450, 35), Vector2(450, 72), Color("#332719"), 3)
	draw_line(Vector2(432, 53), Vector2(468, 53), Color("#332719"), 3)
	draw_string(ThemeDB.fallback_font, Vector2(443, 31), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#332719"))

	if world:
		_draw_region_labels()

func _draw_region_labels() -> void:
	for region in world.regions:
		var p: Vector2 = _map_pos(region["position"])
		var fc: Color = world.get_faction_color(String(region["owner"]))
		draw_circle(p, 10.0, Color("#efe3b3"))
		draw_circle(p, 8.0, fc)
		draw_circle(p, 3.0, Color("#17120d"))

func _map_pos(p: Vector2) -> Vector2:
	return Vector2(20.0 + ((p.x + 22.0) / 44.0) * 455.0, 30.0 + ((p.y + 18.0) / 36.0) * 440.0)

func _draw_mountain(p: Vector2) -> void:
	var pts := PackedVector2Array([p + Vector2(-18,14), p + Vector2(0,-20), p + Vector2(18,14)])
	draw_colored_polygon(pts, Color("#665a4b"))
	draw_polyline(PackedVector2Array([p + Vector2(-18,14),p + Vector2(0,-20),p + Vector2(18,14)]), Color("#30291f"), 2)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-7,-8),p + Vector2(0,-20),p + Vector2(8,-7)]), Color("#e1d8c1"))

func _draw_tree(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-2,5), Vector2(4,12)), Color("#5a3b24"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0,-12),p + Vector2(-12,8),p + Vector2(12,8)]), Color("#315d3a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0,-4),p + Vector2(-9,13),p + Vector2(9,13)]), Color("#264d30"))
