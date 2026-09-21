extends Node2D

var radio := 3.0
var color := Color(1, 0, 0, 1.0)  # rojo puro, bien notorio

func _ready():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "radio", 14.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _process(_delta):
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, radio, color)
