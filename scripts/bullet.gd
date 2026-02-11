extends Area2D

@export var speed := 1000.0
@export var damage := 1

var direction: Vector2 = Vector2.RIGHT

@onready var shape_cast = $ShapeCast2D

func _physics_process(delta):
	var velocity = direction * speed * delta
	
	shape_cast.target_position = to_local(global_position + velocity)
	shape_cast.force_shapecast_update()
	
	if shape_cast.is_colliding():
		# We hit something
		var body = shape_cast.get_collider(0)
		
		if body.has_method("take_damage"):
			body.take_damage(damage)
			
		queue_free()
	else:
		global_position += velocity