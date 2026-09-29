extends Node2D

var radio := 4.0
var color := Color(1, 0.9, 0.4, 1.0)

func _ready():
	var radio_final = radio * 1.3
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "radio", radio_final, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _process(_delta):
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, radio, color)
