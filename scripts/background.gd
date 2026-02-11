extends Sprite2D

@export var scroll_speed : Vector2 = Vector2(20, 10)

func _process(delta: float) -> void:
	region_rect.position += scroll_speed * delta
