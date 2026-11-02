class_name OccluderUtil
extends RefCounted
## Build LightOccluder2D polygons from sprite alpha silhouettes (convex hull).

static func hull_from_texture(tex: Texture2D, step: int = 3, threshold: int = 24) -> PackedVector2Array:
	if tex == null:
		return PackedVector2Array()
	var img: Image = tex.get_image()
	if img == null:
		return PackedVector2Array()
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var pts: Array[Vector2] = []
	for y in range(0, h, step):
		for x in range(0, w, step):
			var a := img.get_pixel(x, y).a
			if a * 255.0 < float(threshold):
				continue
			# edge-ish: keep if any neighbor is transparent
			var edge := false
			for oy in range(-step, step + 1, step):
				for ox in range(-step, step + 1, step):
					if ox == 0 and oy == 0:
						continue
					var nx := clampi(x + ox, 0, w - 1)
					var ny := clampi(y + oy, 0, h - 1)
					if img.get_pixel(nx, ny).a * 255.0 < float(threshold):
						edge = true
						break
				if edge:
					break
			if edge:
				pts.append(Vector2(x - w * 0.5, y - h * 0.5))
	if pts.size() < 3:
		# fallback box
		return PackedVector2Array([
			Vector2(-w * 0.35, -h * 0.45), Vector2(w * 0.35, -h * 0.45),
			Vector2(w * 0.35, h * 0.35), Vector2(-w * 0.35, h * 0.35)
		])
	return _convex_hull(pts)

static func _convex_hull(points: Array[Vector2]) -> PackedVector2Array:
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y)
	)
	var lower: Array[Vector2] = []
	for p in points:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array[Vector2] = []
	for i in range(points.size() - 1, -1, -1):
		var p: Vector2 = points[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)
	lower.pop_back()
	upper.pop_back()
	var hull := PackedVector2Array()
	for p in lower:
		hull.append(p)
	for p in upper:
		hull.append(p)
	return hull

static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

static func make_occluder(tex: Texture2D, offset: Vector2 = Vector2.ZERO) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	occ.name = "Occluder"
	var poly := OccluderPolygon2D.new()
	var hull := hull_from_texture(tex)
	# apply sprite local offset
	var shifted := PackedVector2Array()
	for p in hull:
		shifted.append(p + offset)
	poly.polygon = shifted
	occ.occluder = poly
	return occ
