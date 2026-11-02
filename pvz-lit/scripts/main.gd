extends Node2D
## Playable dusk lawn — readable original silhouettes, staged PVZ board,
## low-sun soft shadows, lantern pools. No PopCap assets.

const COLS := 9
const ROWS := 5
const PLANT_COST := 50
const START_SUN := 200
const MEDIA_DIR := "/cursor/stores/bc-596c6e85-c608-442a-b446-8d642705f24f/media"

# Perspective lawn (matches assets/lawn.png staging)
const LAWN_TOP := 230.0
const LAWN_BOT := 690.0
const LEFT_TOP := 175.0
const RIGHT_TOP := 1085.0
const LEFT_BOT := 155.0
const RIGHT_BOT := 1110.0

var sun_bank: int = START_SUN
var grid: Array = []
var light_angle := 0.15
var zombie_spawn_timer := 9.0
var sun_fall_timer := 4.0
var capture_mode := false
var capture_step := 0
var capture_timer := 0.0
var _frame_dump_dir := ""
var _frame_i := 0
var _frame_accum := 0.0
var _dumping_frames := false

@onready var entities: Node2D = $World/Entities
@onready var lights: Node2D = $World/Lights
@onready var ui_label: Label = $UI/HUD
@onready var canvas_mod: CanvasModulate = $CanvasModulate
@onready var sun_dir: DirectionalLight2D = $World/Lights/SunDir
@onready var env_node: WorldEnvironment = $WorldEnvironment

var plant_tex: Texture2D
var plant_n: Texture2D
var zombie_tex: Texture2D
var zombie_n: Texture2D
var sun_tex: Texture2D
var pea_tex: Texture2D
var cookie: Texture2D
var ground_tex: Texture2D
var ground_n: Texture2D
var lawn_tex: Texture2D
var lamp_tex: Texture2D
var lamp_n: Texture2D

func _ready() -> void:
	capture_mode = OS.get_environment("PVZ_CAPTURE") == "1" or "--capture" in OS.get_cmdline_user_args()
	_load_textures()
	_build_lawn_receivers()
	_place_lane_shadows()
	_place_planterns()
	_init_grid()
	_configure_lighting()
	_place_god_rays()
	_update_hud()
	_seed_demo()
	if capture_mode:
		capture_timer = 0.15
		print("PVZ Lit Slice CAPTURE mode → ", MEDIA_DIR)
	else:
		print("PVZ Lit Slice ready — LMB plant/collect | D soft shadows | L lamps")

func _load_textures() -> void:
	lawn_tex = load("res://assets/lawn.png")
	plant_tex = load("res://assets/plant.png")
	plant_n = load("res://assets/plant_n.png")
	zombie_tex = load("res://assets/zombie.png")
	zombie_n = load("res://assets/zombie_n.png")
	sun_tex = load("res://assets/sun.png")
	pea_tex = load("res://assets/pea.png")
	cookie = load("res://assets/light_cookie.png")
	ground_tex = load("res://assets/ground_tile.png")
	ground_n = load("res://assets/ground_n.png")
	lamp_tex = load("res://assets/lamp.png")
	lamp_n = load("res://assets/lamp_n.png")
	$World/LawnBG.texture = lawn_tex
	# Dim the painted BG slightly so lit receivers + lamps read as the lit plane
	# Keep painted house/sky/fence readable; grass lit mainly by receivers
	$World/LawnBG.modulate = Color(0.88, 0.9, 0.95, 1.0)

func _canvas_tex(diffuse: Texture2D, normal: Texture2D) -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = diffuse
	ct.normal_texture = normal
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return ct

func _configure_lighting() -> void:
	# Lifted grade: unlit rows stay readable; shadows soft, not crushed black
	canvas_mod.color = Color(0.28, 0.30, 0.38, 1.0)
	sun_dir.energy = 1.55
	sun_dir.color = Color(1.0, 0.78, 0.5)
	sun_dir.shadow_enabled = true
	sun_dir.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	sun_dir.shadow_filter_smooth = 2.2
	sun_dir.shadow_color = Color(0.08, 0.1, 0.16, 0.55)
	sun_dir.height = 0.32
	sun_dir.max_distance = 2600.0
	sun_dir.rotation = -1.18
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_strength = 1.0
	env.glow_bloom = 0.4
	env.glow_hdr_threshold = 0.75
	env.glow_hdr_scale = 1.2
	env.glow_mix = 0.08
	env.set_glow_level(1, false)
	env.set_glow_level(2, true)
	env.set_glow_level(3, true)
	env.set_glow_level(4, true)
	env.set_glow_level(5, true)
	env.set_glow_level(6, true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.2
	env.tonemap_white = 5.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.02
	env_node.environment = env
	var rim := PointLight2D.new()
	rim.name = "MoonFill"
	rim.texture = cookie
	rim.texture_scale = 16.0
	rim.energy = 0.42
	rim.color = Color(0.45, 0.55, 0.85)
	rim.height = 1.2
	rim.shadow_enabled = false
	rim.position = Vector2(700, 420)
	lights.add_child(rim)

func _place_lane_shadows() -> void:
	# Soft dark bands between rows → deeper unlit gutters (not a wash)
	var layer := $World/Ground
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.06, 0.1, 0.16))
	var tex := ImageTexture.create_from_image(img)
	for r in range(ROWS - 1):
		var y0 := _row_y_range(r).y
		var y1 := _row_y_range(r + 1).x
		var y := (y0 + y1) * 0.5
		var wr := _width_at_y(y)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.position = Vector2((wr.x + wr.y) * 0.5, y)
		s.scale = Vector2((wr.y - wr.x) / 8.0, 18.0 / 8.0)
		s.z_index = 2
		layer.add_child(s)

func _place_god_rays() -> void:
	# Soft additive shafts from low sun across the lawn — subtle, not washed out
	var ray_tex: Texture2D = load("res://assets/godray.png")
	var rays := Node2D.new()
	rays.name = "GodRays"
	rays.z_index = 3
	$World.add_child(rays)
	# Painted sun sits mid-horizon; shafts fan across rows
	var origin := Vector2(640, 165)
	var angles := [-1.05, -0.78, -0.52, -0.28, -0.05]
	for i in range(angles.size()):
		var spr := Sprite2D.new()
		spr.texture = ray_tex
		spr.centered = false
		spr.offset = Vector2(-128, 0)
		spr.position = origin
		spr.rotation = angles[i]
		spr.scale = Vector2(0.35 + float(i % 2) * 0.08, 1.55)
		spr.modulate = Color(1.0, 0.88, 0.6, 0.2)
		spr.z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr.material = mat
		rays.add_child(spr)
	rays.set_meta("t", 0.0)

func _row_y_range(row: int) -> Vector2:
	var t0 := float(row) / float(ROWS)
	var t1 := float(row + 1) / float(ROWS)
	return Vector2(lerpf(LAWN_TOP, LAWN_BOT, t0), lerpf(LAWN_TOP, LAWN_BOT, t1))

func _width_at_y(y: float) -> Vector3:
	# returns left, right, t
	var t := clampf((y - LAWN_TOP) / (LAWN_BOT - LAWN_TOP), 0.0, 1.0)
	var left := lerpf(LEFT_TOP, LEFT_BOT, t)
	var right := lerpf(RIGHT_TOP, RIGHT_BOT, t)
	return Vector3(left, right, t)

func _cell_center(col: int, row: int) -> Vector2:
	var yr := _row_y_range(row)
	var y := lerpf(yr.x, yr.y, 0.62)
	var wr := _width_at_y(y)
	var x := lerpf(wr.x, wr.y, (float(col) + 0.5) / float(COLS))
	return Vector2(x, y)

func _cell_scale(row: int) -> float:
	# Nearer rows (higher index) slightly larger — staged depth
	return lerpf(0.78, 1.12, float(row) / float(ROWS - 1))

func _build_lawn_receivers() -> void:
	# Continuous grass row strips (not cell pills / neon grid) to catch light + long shadows.
	var layer := $World/Ground
	for r in range(ROWS):
		var mid := _cell_center(COLS / 2, r)
		var sc := _cell_scale(r)
		var strip := Sprite2D.new()
		strip.texture = _canvas_tex(ground_tex, ground_n)
		strip.centered = true
		strip.position = mid + Vector2(0, 10)
		strip.scale = Vector2(5.2 * sc, 0.72 * sc)
		strip.modulate = Color(0.92, 1.0, 0.88, 1.0)
		strip.z_index = 0
		layer.add_child(strip)
		# Slight front lip so rows read as staged beds
		var lip := Sprite2D.new()
		lip.texture = _canvas_tex(ground_tex, ground_n)
		lip.centered = true
		lip.position = mid + Vector2(0, 28 * sc)
		lip.scale = Vector2(5.0 * sc, 0.28 * sc)
		lip.modulate = Color(0.55, 0.7, 0.48, 0.9)
		lip.z_index = 1
		layer.add_child(lip)

func _place_planterns() -> void:
	var spots := [Vector2i(2, 1), Vector2i(5, 3), Vector2i(7, 2)]
	for cell in spots:
		var root := Node2D.new()
		root.name = "Plantern_%d_%d" % [cell.x, cell.y]
		var sc := _cell_scale(cell.y)
		root.position = _cell_center(cell.x, cell.y) + Vector2(0, 6)
		root.z_index = 12 + cell.y
		root.scale = Vector2(sc, sc)
		var spr := Sprite2D.new()
		spr.texture = _canvas_tex(lamp_tex, lamp_n)
		spr.centered = true
		spr.position = Vector2(0, -50)
		root.add_child(spr)
		root.add_child(OccluderUtil.make_occluder(lamp_tex, Vector2(0, -50)))
		# Warm pool lighting nearby cells
		var pl := PointLight2D.new()
		pl.name = "LampLight"
		pl.texture = cookie
		pl.texture_scale = 4.2 / sc
		pl.energy = 1.85
		pl.color = Color(1.0, 0.78, 0.38)
		pl.height = 0.45
		pl.shadow_enabled = true
		pl.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		pl.shadow_filter_smooth = 1.8
		pl.shadow_color = Color(0.1, 0.06, 0.02, 0.45)
		pl.position = Vector2(0, -62)
		root.add_child(pl)
		var core := PointLight2D.new()
		core.name = "LampCore"
		core.texture = cookie
		core.texture_scale = 1.35 / sc
		core.energy = 2.6
		core.color = Color(1.0, 0.95, 0.65)
		core.height = 0.95
		core.shadow_enabled = false
		core.position = Vector2(0, -62)
		root.add_child(core)
		entities.add_child(root)

func _init_grid() -> void:
	grid.clear()
	for r in range(ROWS):
		var row: Array = []
		row.resize(COLS)
		for c in range(COLS):
			row[c] = null
		grid.append(row)

func _seed_demo() -> void:
	_force_plant(1, 2)
	_force_plant(2, 2)
	_force_plant(1, 4)
	_force_plant(3, 3)
	_force_plant(0, 1)
	# Spawn mid-lawn so walk + shoot are visible early in capture clip
	_spawn_zombie_at(2, 0.62)
	_spawn_zombie_at(4, 0.7)
	_spawn_zombie_at(3, 0.55)
	_spawn_falling_sun_at(4, 2)

func _force_plant(col: int, row: int) -> void:
	if grid[row][col] != null:
		return
	var p := _make_plant(col, row)
	grid[row][col] = p
	entities.add_child(p)

func _cell_from_pos(p: Vector2) -> Vector2i:
	if p.y < LAWN_TOP or p.y > LAWN_BOT:
		return Vector2i(-1, -1)
	var row := int(clampf(floor((p.y - LAWN_TOP) / (LAWN_BOT - LAWN_TOP) * ROWS), 0, ROWS - 1))
	var wr := _width_at_y(p.y)
	if p.x < wr.x or p.x > wr.y:
		return Vector2i(-1, -1)
	var col := int(clampf(floor((p.x - wr.x) / (wr.y - wr.x) * COLS), 0, COLS - 1))
	return Vector2i(col, row)

func _process(delta: float) -> void:
	light_angle += delta * 0.07
	# Keep sun low; gentle sweep for living shadows across rows
	sun_dir.rotation = -1.25 + sin(light_angle) * 0.35
	sun_dir.energy = 1.55 + 0.25 * (0.5 + 0.5 * sin(light_angle * 0.5))
	var t := 0.5 + 0.5 * sin(light_angle * 0.35)
	sun_dir.color = Color(1.0, lerp(0.62, 0.82, t), lerp(0.32, 0.52, t))
	canvas_mod.color = Color(lerp(0.24, 0.32, t), lerp(0.26, 0.34, t), lerp(0.34, 0.42, 1.0 - t), 1.0)
	for n in entities.get_children():
		if str(n.name).begins_with("Plantern_"):
			var pl := n.get_node_or_null("LampLight") as PointLight2D
			var core := n.get_node_or_null("LampCore") as PointLight2D
			if pl:
				pl.energy = 1.65 + 0.35 * sin(Time.get_ticks_msec() * 0.0025 + n.position.x * 0.01)
			if core:
				core.energy = 2.3 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + n.position.y * 0.02)
	var rays := $World.get_node_or_null("GodRays")
	if rays:
		var rt: float = float(rays.get_meta("t")) + delta
		rays.set_meta("t", rt)
		for c in rays.get_children():
			var spr := c as Sprite2D
			if spr:
				spr.modulate.a = 0.12 + 0.06 * sin(rt * 0.7 + spr.rotation * 3.0)

	if capture_mode:
		_run_capture(delta)
		if _dumping_frames:
			_frame_accum += delta
			# ~15 fps dump — enough to read walk/shoot without huge IO
			if _frame_accum >= 1.0 / 15.0:
				_frame_accum = 0.0
				_dump_motion_frame()
		sun_fall_timer -= delta
		if sun_fall_timer <= 0.0:
			sun_fall_timer = 3.5
			_spawn_falling_sun()
		return

	sun_fall_timer -= delta
	if sun_fall_timer <= 0.0:
		sun_fall_timer = randf_range(5.0, 8.0)
		_spawn_falling_sun()
	zombie_spawn_timer -= delta
	if zombie_spawn_timer <= 0.0:
		zombie_spawn_timer = randf_range(7.5, 12.0)
		_spawn_zombie(randi_range(0, ROWS - 1))

func _run_capture(delta: float) -> void:
	capture_timer -= delta
	if capture_timer > 0.0:
		return
	if capture_step == 0:
		capture_step = 10
		_capture_sequence()

func _capture_sequence() -> void:
	# Engine-side frame dump (X11 grab was unreliable / frozen). Then stills + encode.
	_frame_dump_dir = "/tmp/pvz-lit-frames"
	DirAccess.make_dir_recursive_absolute(_frame_dump_dir)
	# Clear old frames
	var da := DirAccess.open(_frame_dump_dir)
	if da:
		da.list_dir_begin()
		var fn := da.get_next()
		while fn != "":
			if fn.ends_with(".png"):
				da.remove(fn)
			fn = da.get_next()
	_frame_i = 0
	_frame_accum = 0.0
	_dumping_frames = true
	await get_tree().create_timer(1.2).timeout
	await _save_shot("pvz-lit-dusk-board.png")
	_force_plant(4, 2)
	sun_dir.rotation = -0.9
	await get_tree().create_timer(2.0).timeout
	await _save_shot("pvz-lit-lamp-shadows.png")
	# Keep dumping walk/shoot frames
	await get_tree().create_timer(5.0).timeout
	_dumping_frames = false
	print("FRAMES_DUMPED ", _frame_i, " → ", _frame_dump_dir)
	print("CAPTURE_DONE")
	get_tree().quit()

func _save_shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("screenshot failed")
		return
	DirAccess.make_dir_recursive_absolute(MEDIA_DIR)
	var path := MEDIA_DIR.path_join(filename)
	var err := img.save_png(path)
	print("SAVED ", path, " err=", err, " ", img.get_width(), "x", img.get_height())

func _dump_motion_frame() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	var path := "%s/frame_%04d.png" % [_frame_dump_dir, _frame_i]
	img.save_png(path)
	_frame_i += 1

func _unhandled_input(event: InputEvent) -> void:
	if capture_mode:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			sun_dir.shadow_filter_smooth = 2.8 if sun_dir.shadow_filter_smooth < 2.4 else 1.6
			return
		if event.keycode == KEY_L:
			for n in entities.get_children():
				if str(n.name).begins_with("Plantern_"):
					var pl := n.get_node_or_null("LampLight") as PointLight2D
					if pl:
						pl.visible = not pl.visible
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_global_mouse_position()
		for s in get_tree().get_nodes_in_group("suns"):
			if s.global_position.distance_to(mp) < 44.0:
				_collect_sun(s)
				return
		var cell := _cell_from_pos(mp)
		if cell.x >= 0 and cell.y >= 0:
			_try_plant(cell.x, cell.y)

func _try_plant(col: int, row: int) -> void:
	if grid[row][col] != null:
		return
	if sun_bank < PLANT_COST:
		_flash_hud("Need %d sun" % PLANT_COST)
		return
	sun_bank -= PLANT_COST
	_update_hud()
	_force_plant(col, row)

func _make_plant(col: int, row: int) -> Node2D:
	var root := Node2D.new()
	root.set_script(load("res://scripts/plant.gd"))
	var sc := _cell_scale(row)
	root.position = _cell_center(col, row) + Vector2(0, 4)
	root.z_index = 14 + row
	root.scale = Vector2(sc, sc)
	root.set("row", row)
	root.set("col", col)
	root.set("pea_tex", pea_tex)
	root.set("entities", entities)
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = _canvas_tex(plant_tex, plant_n)
	spr.centered = true
	spr.position = Vector2(0, -48)
	spr.modulate = Color(1.1, 1.1, 1.06, 1.0)
	root.add_child(spr)
	root.add_child(OccluderUtil.make_occluder(plant_tex, Vector2(0, -48)))
	var pl := PointLight2D.new()
	pl.name = "Fill"
	pl.texture = cookie
	pl.texture_scale = 1.1 / sc
	pl.energy = 0.28
	pl.color = Color(0.65, 1.0, 0.55)
	pl.height = 0.35
	pl.shadow_enabled = false
	pl.position = Vector2(0, -46)
	root.add_child(pl)
	return root

func _spawn_zombie(row: int) -> void:
	_spawn_zombie_at(row, 1.05)

func _spawn_zombie_at(row: int, x_frac: float) -> void:
	var z := Node2D.new()
	z.set_script(load("res://scripts/zombie.gd"))
	var sc := _cell_scale(row)
	var start := _cell_center(COLS - 1, row)
	var wr := _width_at_y(start.y)
	z.position = Vector2(lerpf(wr.x, wr.y, clampf(x_frac, 0.0, 1.15)), start.y)
	z.z_index = 14 + row
	z.scale = Vector2(sc, sc)
	z.set("row", row)
	z.set("grid_ref", self)
	z.set("speed", 24.0 + float(row) * 1.5)
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = _canvas_tex(zombie_tex, zombie_n)
	spr.centered = true
	spr.position = Vector2(0, -62)
	spr.modulate = Color(1.14, 1.12, 1.16, 1.0)
	z.add_child(spr)
	z.add_child(OccluderUtil.make_occluder(zombie_tex, Vector2(0, -62)))
	entities.add_child(z)

func _spawn_falling_sun() -> void:
	_spawn_falling_sun_at(randi_range(1, COLS - 2), randi_range(0, ROWS - 1))

func _spawn_falling_sun_at(col: int, row: int) -> void:
	var s := Area2D.new()
	s.set_script(load("res://scripts/sun_token.gd"))
	s.add_to_group("suns")
	var dest := _cell_center(col, row)
	s.position = Vector2(dest.x, 50.0)
	s.set("target_y", dest.y - 24.0)
	s.set("sun_tex", sun_tex)
	s.set("cookie", cookie)
	s.z_index = 40
	entities.add_child(s)

func _collect_sun(token: Node) -> void:
	sun_bank += 25
	_update_hud()
	var flash := PointLight2D.new()
	flash.texture = cookie
	flash.texture_scale = 2.6
	flash.energy = 3.0
	flash.color = Color(1.0, 0.92, 0.5)
	flash.position = token.global_position
	flash.height = 0.9
	lights.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "energy", 0.0, 0.55)
	tw.tween_callback(flash.queue_free)
	token.queue_free()

func plant_at(col: int, row: int) -> Node:
	if row < 0 or row >= ROWS or col < 0 or col >= COLS:
		return null
	return grid[row][col]

func clear_plant(col: int, row: int) -> void:
	if row < 0 or row >= ROWS or col < 0 or col >= COLS:
		return
	var p = grid[row][col]
	grid[row][col] = null
	if p and is_instance_valid(p):
		p.queue_free()

func _update_hud() -> void:
	ui_label.text = "SUN %d  |  LMB plant(%d)/collect  |  D soft shadows  |  L lamps" % [sun_bank, PLANT_COST]

func _flash_hud(msg: String) -> void:
	ui_label.text = msg
	await get_tree().create_timer(0.8).timeout
	_update_hud()
