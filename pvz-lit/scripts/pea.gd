extends Area2D

var row: int = 0
var pea_tex: Texture2D
var speed := 300.0
var damage := 20.0

func _ready() -> void:
	var spr := Sprite2D.new()
	spr.texture = pea_tex
	spr.centered = true
	spr.scale = Vector2(1.15, 1.15)
	add_child(spr)
	var main := get_tree().current_scene
	if main and main.get("cookie"):
		var pl := PointLight2D.new()
		pl.texture = main.cookie
		pl.texture_scale = 0.85
		pl.energy = 1.65
		pl.color = Color(0.55, 1.0, 0.45)
		pl.height = 0.55
		add_child(pl)
		# bright core for bloom
		var core := PointLight2D.new()
		core.texture = main.cookie
		core.texture_scale = 0.35
		core.energy = 2.4
		core.color = Color(0.85, 1.0, 0.7)
		core.height = 0.8
		add_child(core)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	cs.shape = shape
	add_child(cs)

func _process(delta: float) -> void:
	position.x += speed * delta
	for z in get_tree().get_nodes_in_group("zombies"):
		if int(z.get("row")) == row and global_position.distance_to(z.global_position + Vector2(0, -40)) < 42.0:
			if z.has_method("take_damage"):
				z.take_damage(damage)
			queue_free()
			return
	if position.x > 1400.0:
		queue_free()
