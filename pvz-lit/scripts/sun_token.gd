extends Area2D

var target_y: float = 400.0
var sun_tex: Texture2D
var cookie: Texture2D
var fall_speed := 55.0
var life := 12.0
var _bob_t := 0.0
var _landed := false

func _ready() -> void:
	_bob_t = randf() * TAU
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	var ct := CanvasTexture.new()
	ct.diffuse_texture = sun_tex
	var npath := "res://assets/sun_n.png"
	if ResourceLoader.exists(npath):
		ct.normal_texture = load(npath)
	spr.texture = ct
	spr.centered = true
	add_child(spr)
	var pl := PointLight2D.new()
	pl.name = "Glow"
	pl.texture = cookie
	pl.texture_scale = 2.4
	pl.energy = 2.1
	pl.color = Color(1.0, 0.9, 0.45)
	pl.height = 0.8
	pl.shadow_enabled = false
	add_child(pl)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	cs.shape = shape
	add_child(cs)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_bob_t += delta
	if position.y < target_y:
		position.y = minf(target_y, position.y + fall_speed * delta)
		_landed = false
	else:
		_landed = true
	var spr := get_node_or_null("Sprite") as Node2D
	if spr:
		# Clear bob after landing; slight sway while falling
		if _landed:
			spr.position.y = sin(_bob_t * 3.2) * 6.0
			spr.rotation = sin(_bob_t * 2.1) * 0.18
			spr.scale = Vector2.ONE * (1.0 + sin(_bob_t * 3.2) * 0.04)
		else:
			spr.rotation = sin(_bob_t * 4.0) * 0.12
	var glow := get_node_or_null("Glow") as PointLight2D
	if glow:
		glow.energy = 1.7 + 0.45 * sin(_bob_t * 4.0)
