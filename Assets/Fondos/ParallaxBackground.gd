extends ParallaxBackground


@onready var Blue_Sky = $"Cielo Azul"
@onready var Clouds = $Cielo
@onready var Montain = $"Montañas"
@onready var Grass = $Cesped

func _process(delta):
	# Preserve la velocidad aproximada a 60 FPS, sin depender de la tasa de cuadros.
	Blue_Sky.motion_offset.x -= 0.6 * delta
	Clouds.motion_offset.x -= 15.0 * delta
	
