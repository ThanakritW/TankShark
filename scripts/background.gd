extends Sprite2D

@export var scroll_speed : Vector2 = Vector2(20, 10)

func _process(delta: float) -> void:
	# Move the region_rect position to create a scrolling/flowing effect
	region_rect.position += scroll_speed * delta
