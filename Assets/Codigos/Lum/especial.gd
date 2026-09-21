extends Area2D

var speed = 300
var direction = 1
var daño: int = 10
var duración_hitstun: float = 0.35
@export var vida_util: float = 2.0

func _ready():
	# Volteamos el proyectil hacia donde mira el jugador
	scale.x = direction
	# Si no choca con una pared, se elimina fuera de la zona de combate en vez
	# de acumular nodos y partículas indefinidamente.
	await get_tree().create_timer(vida_util).timeout
	if is_instance_valid(self):
		destruir()

func _physics_process(delta):
	# Movimiento constante del proyectil
	position.x += speed * direction * delta


# Al chocar contra un cuerpo (suelo, pared, etc.)
func _on_body_entered(body):
	destruir()


func destruir():
	var rastro = $Rastro
	if rastro:
		# Apagamos la emisión para que no sigan saliendo partículas nuevas
		rastro.emitting = false
		# Desacoplamos el rastro para que los puntos que ya están en el mapa se desvanezcan solos
		rastro.reparent(get_parent())
	
	# Destruimos el proyectil de inmediato.
	queue_free()
