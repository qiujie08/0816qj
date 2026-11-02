extends Node2D
## Walker with short readable walk cycle + bite.

var row: int = 0
var grid_ref: Node = null
var speed := 28.0
var hp := 120.0
var eating := false
var eat_target: Node2D = null
var _phase := 0.0
var _base_scale := Vector2.ONE

func _ready() -> void:
	add_to_group("zombies")
	_phase = randf() * TAU
	_base_scale = scale

func _process(delta: float) -> void:
	var spr := get_node_or_null("Sprite") as Sprite2D
	if eating and is_instance_valid(eat_target):
		eat_target.take_damage(25.0 * delta)
		# bite bob
		if spr:
			spr.position.y = -62.0 + sin(Time.get_ticks_msec() * 0.02) * 3.0
			spr.rotation = sin(Time.get_ticks_msec() * 0.018) * 0.06
		if not is_instance_valid(eat_target):
			eating = false
			eat_target = null
		return
	eating = false
	eat_target = null
	position.x -= speed * delta
	_phase += delta * 7.5
	# Walk cycle: bob + sway + alternate squash (reads as steps)
	if spr:
		spr.position.y = -62.0 + absf(sin(_phase)) * 5.5
		spr.rotation = sin(_phase) * 0.10
		var squash := 1.0 + sin(_phase * 2.0) * 0.04
		var stretch := 1.0 - sin(_phase * 2.0) * 0.035
		scale = Vector2(_base_scale.x * squash, _base_scale.y * stretch)
	if grid_ref and grid_ref.has_method("plant_at"):
		for c in range(9):
			var p = grid_ref.plant_at(c, row)
			if p and is_instance_valid(p):
				if absf(p.global_position.x - global_position.x) < 48.0:
					eating = true
					eat_target = p
					return
	if position.x < 165.0:
		queue_free()

func take_damage(amount: float) -> void:
	hp -= amount
	modulate = Color(1.5, 1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)
	if hp <= 0.0:
		var parent := get_parent()
		if parent:
			var cookie: Texture2D = null
			var main := get_tree().current_scene
			if main != null:
				cookie = main.get("cookie") as Texture2D
			if cookie:
				var burst := PointLight2D.new()
				burst.texture = cookie
				burst.texture_scale = 1.4
				burst.energy = 2.0
				burst.color = Color(1.0, 0.4, 0.2)
				burst.global_position = global_position
				parent.add_child(burst)
				var tw2 := parent.create_tween()
				tw2.tween_property(burst, "energy", 0.0, 0.35)
				tw2.tween_callback(burst.queue_free)
		queue_free()
