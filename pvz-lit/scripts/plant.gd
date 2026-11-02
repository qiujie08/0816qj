extends Node2D
## Peashooter: idle breathe + readable shoot squash.

var row: int = 0
var col: int = 0
var pea_tex: Texture2D
var entities: Node2D
var cooldown := 0.0
var hp := 100.0
var _shooting := false
var _idle_t := 0.0

func _process(delta: float) -> void:
	_idle_t += delta
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr and not _shooting:
		# Subtle idle breathe so board feels alive between shots
		spr.scale = Vector2(1.0 + sin(_idle_t * 2.2) * 0.02, 1.0 - sin(_idle_t * 2.2) * 0.015)
		spr.rotation = sin(_idle_t * 1.4) * 0.03
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0 and _zombie_ahead():
		_shoot()
		cooldown = 1.15

func _zombie_ahead() -> bool:
	for z in get_tree().get_nodes_in_group("zombies"):
		if int(z.get("row")) == row and z.global_position.x > global_position.x - 10.0:
			return true
	return false

func _shoot() -> void:
	_shooting = true
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr:
		# Recoil squash then snap — readable shoot motion
		var tw := create_tween()
		tw.tween_property(spr, "scale", Vector2(1.18, 0.86), 0.06)
		tw.parallel().tween_property(spr, "rotation", -0.12, 0.06)
		tw.tween_property(spr, "scale", Vector2(0.92, 1.12), 0.07)
		tw.parallel().tween_property(spr, "rotation", 0.08, 0.07)
		tw.tween_property(spr, "scale", Vector2.ONE, 0.10)
		tw.parallel().tween_property(spr, "rotation", 0.0, 0.10)
		tw.tween_callback(func() -> void: _shooting = false)
	else:
		_shooting = false
	var pea := Area2D.new()
	pea.set_script(load("res://scripts/pea.gd"))
	pea.global_position = global_position + Vector2(52, -58)
	pea.z_index = z_index + 1
	pea.set("row", row)
	pea.set("pea_tex", pea_tex)
	entities.add_child(pea)
	var flash: PointLight2D = get_node_or_null("Muzzle")
	if flash == null:
		flash = PointLight2D.new()
		flash.name = "Muzzle"
		flash.texture = (get_node("Fill") as PointLight2D).texture
		flash.texture_scale = 0.95
		flash.color = Color(0.7, 1.0, 0.55)
		flash.height = 0.55
		flash.position = Vector2(46, -58)
		add_child(flash)
	flash.energy = 2.4
	var tw2 := create_tween()
	tw2.tween_property(flash, "energy", 0.0, 0.22)

func take_damage(amount: float) -> void:
	hp -= amount
	modulate = Color(1.4, 0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		var main := get_tree().current_scene
		if main and main.has_method("clear_plant"):
			main.clear_plant(col, row)
		else:
			queue_free()
